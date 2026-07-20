#!/usr/bin/env python3
"""Build a broad, provenance-preserving catalog of public text encodings.

The catalog deliberately includes coded character sets, vendor code pages,
Unicode transfer formats, font/glyph encodings, terminal sets, telegraph codes,
and historical component sets.  It does not pretend that undocumented private
encodings can be enumerated.

Run with the Codex bundled Python (which includes pypdf), or install pypdf:

    python3 tools/build_encoding_catalog.py
"""

from __future__ import annotations

import ast
import csv
import email.utils
import hashlib
import html
import io
import json
import re
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict, deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "research"
CACHE_DIR = ROOT / "tmp/encoding-catalog-http"
USER_AGENT = "Iconvex encoding catalog research/1.0"

IANA_URL = "https://www.iana.org/assignments/character-sets/character-sets-1.csv"
WHATWG_URL = "https://encoding.spec.whatwg.org/encodings.json"
ICU_URL = (
    "https://raw.githubusercontent.com/unicode-org/icu/main/"
    "icu4c/source/data/mappings/convrtrs.txt"
)
GLIBC_URLS = (
    "https://raw.githubusercontent.com/bminor/glibc/master/iconvdata/gconv-modules",
    "https://raw.githubusercontent.com/bminor/glibc/master/iconvdata/gconv-modules-extra.conf",
)
OPENJDK_CHARSETS_URL = (
    "https://raw.githubusercontent.com/openjdk/jdk/master/make/data/charsetmapping/charsets"
)
PYTHON_ALIASES_URL = (
    "https://raw.githubusercontent.com/python/cpython/main/Lib/encodings/aliases.py"
)
PYTHON_ENCODINGS_API = (
    "https://api.github.com/repos/python/cpython/contents/Lib/encodings?per_page=1000"
)
MICROSOFT_URL = "https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers"
IBM_I_URL = (
    "https://www.ibm.com/docs/en/i/7.4.0?topic=information-ccsid-values-defined-i"
)
RFC1345_URL = "https://www.rfc-editor.org/rfc/rfc1345.txt"
KERMIT_URL = "https://www.kermitproject.org/k95charsets.html"
ISO_IR_ARCHIVE_URL = (
    "https://web.archive.org/web/20240218150849id_/"
    "https://itscj.ipsj.or.jp/english/vbcqpr00000004qn-att/ISO-IR.pdf"
)
WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"
WIKIPEDIA_HISTORICAL_URL = (
    "https://en.wikipedia.org/wiki/List_of_information_system_character_sets"
)
PUNCHED_CARD_CODES_URL = "https://homepage.cs.uiowa.edu/~jones/cards/codes.html"
UNICODE_MAPPING_ROOTS = (
    "https://www.unicode.org/Public/MAPPINGS/VENDORS/",
    "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/",
)
GNU_URL = "https://www.gnu.org/software/libiconv/"

SOURCE_PRIORITY = {
    "iana": 0,
    "whatwg": 1,
    "gnu_libiconv": 2,
    "glibc": 3,
    "icu": 4,
    "openjdk": 5,
    "microsoft": 6,
    "ibm_i": 7,
    "iso_ir": 8,
    "rfc1345": 9,
    "unicode_mappings": 10,
    "python": 11,
    "kermit": 12,
    "wikidata": 13,
    "wikipedia_historical": 14,
    "punched_cards": 15,
    "wikipedia": 16,
    "supplement": 17,
}

# Labels too vague to merge safely across sources.  They remain visible aliases.
AMBIGUOUS_KEYS = {
    "arabic",
    "chinese",
    "cyrillic",
    "default",
    "dingbats",
    "greek",
    "hebrew",
    "internal",
    "japanese",
    "korean",
    "latin",
    "mac",
    "roman",
    "symbol",
    "thai",
    "unicode",
    "unknown",
}

# Exact source-title bridges reviewed against primary mapping tables. These are
# applied only to canonical-name grouping, never as globally transitive aliases.
AUDITED_CANONICAL_MERGES = {
    "americannationalstandardextendedlatinalphabetcodedcharactersetforbibliographicuseansel": "ansel",
    "americannationalstandardforextendedlatinalphabetcodedcharactersetforbibliographicuse": "ansel",
    "arabiciso": "iso88596",
    "binaryorderedcompressionforunicode": "bocu1",
    "canadianfrench": "csaz243419851",
    "ccit2": "ita2",
    "compatibilityencodingschemeforutf168bit": "cesu8",
    "cyrilliciso": "iso88595",
    "danish": "ds2089",
    "decspecial": "decspecialgraphics",
    "decspecialgraphicscharacterset": "decspecialgraphics",
    "dectechnical": "dectechnicalcharacterset",
    "elot928greek": "greekiso",
    "french": "nfz620101973",
    "elot927": "greek7",
    "german": "din66003",
    "italian": "it",
    "japaneseroman": "jisc62201969ro",
    "koi8cryillic": "koi8",
    "koi7": "shortkoi",
    "latin1iso": "iso88591",
    "latin2iso": "iso88592",
    "latin3iso": "iso88593",
    "latin4iso": "iso88594",
    "latin5iso": "iso88599",
    "latin9iso": "iso885915",
    "multinationalcharacterset": "decmcs",
    "norwegian": "ds2089",
    "spanish": "es",
    "hebrew7": "si960",
    "ibm1401cardcode": "ibm1401card",
    "ibm026commercialcardcode": "ibm2426specialcharacterarrangementa",
    "ibm026fortrancardcode": "ibm2426specialcharacterarrangementh",
    "ibmhcodeprogramming": "ibm7040hprogram",
    "ibmhcodereportwriting": "ibm7040hreport",
    "hkscs1999": "big5hkscs1999",
    "hkscs2001": "big5hkscs2001",
    "hkscs2004": "big5hkscs2004",
    "hkscs2008": "big5hkscs",
    "itut51": "iso6937",
    "koi8e": "ecmacyrillic",
    "maccroatianencoding": "maccroatian",
    "macintoshlatinencoding": "macintoshlatin",
    "macintoshcentraleuropeanencoding": "maccentraleurope",
    "macintoshcyrillicencoding": "xmaccyrillic",
    "macintoshukrainianencoding": "macukraine",
    "macoscentraleuropeanencoding": "maccentraleurope",
    "macoschinesesimplified": "macoschinsimp",
    "macoscroatianencoding": "maccroatian",
    "macoscyrillicencoding": "xmaccyrillic",
    "macosgreekencoding": "macgreek",
    "macosicelandicencoding": "maciceland",
    "macosromanianencoding": "macosromanian",
    "macosturkishencoding": "macturkish",
    "macosukrainianencoding": "macukraine",
    "macromanianencoding": "macosromanian",
    "macturkishencoding": "macturkish",
    "mazoviaencoding": "mazovia",
    "mikcodepage": "mik",
    "nextcharacterset": "nextstep",
    "nextcodepage": "nextstep",
    "q8815": "usascii",
    "standardcompressionschemeforunicode": "scsu",
    # Wikipedia's TACE16 article is a direct redirect/concept duplicate of
    # Tamil All Character Encoding.  Keep TACE16 as a visible catalog alias,
    # while merging its source record into the exact implemented concept.
    "tace16": "tamilallcharacterencoding",
    "t51isoiec6937": "iso6937",
    "wobblytransformationformat": "wtf8",
    "ebcdic037": "ibm037",
    "ebcdic1025": "ibm1025",
    "ebcdic1026": "ibm1026",
    "ebcdic1047": "ibm1047",
    "ebcdic273": "ibm273",
    "ebcdic277": "ibm277",
    "ebcdic278": "ibm278",
    "ebcdic280": "ibm280",
    "ebcdic284": "ibm284",
    "ebcdic285": "ibm285",
    "ebcdic297": "ibm297",
    "ebcdic423": "ibm423",
    "ebcdic424": "ibm424",
    "ebcdic500": "ibm500",
    "ebcdic870": "ibm870",
    "ebcdic871": "ibm871",
    "ebcdic875": "ibm875",
    "ebcdic880": "ibm880",
    "ebcdic905": "ibm905",
    "ebcdic924": "ibm924",
}

# Wikidata's authoritative entity data names Q17190477 only in Japanese, so
# the English-only SPARQL label service returns the opaque entity identifier.
# Preserve the human-readable entity label from
# https://www.wikidata.org/wiki/Special:EntityData/Q17190477.json.
AUDITED_WIKIDATA_FALLBACK_LABELS = {
    "Q17190477": "U-PRESS",
}

# Exact source identities whose cited IBM names are declared aliases by the
# pinned GNU libiconv 1.19 `encodings.def`.  Source IDs are used deliberately:
# generic CP932/CP949 labels denote several independently versioned mappings
# elsewhere in the catalog and must not become transitive aliases.
AUDITED_GNU_SOURCE_ID_MERGES = {
    "wikidata:Q25000674": "cp932",
    "wikipedia:pageid 2996905": "cp932",
    "wikidata:Q48739550": "cp949",
    "wikipedia:pageid 49785516": "cp949",
}

# Source-audited records that are adjacent to character encodings but do not
# identify one portable character-to-byte mapping.  Family dispositions are
# deliberately non-coverage-bearing: concrete child codecs remain separate
# catalog records and must be implemented or blocked on their own evidence.
AUDITED_NON_CODEC_DISPOSITIONS = {
    "adobejapan1": "repertoire_profile",
    "advancedvideoattributeterminalassemblerandrecreator": "terminal_protocol",
    "alphanumeric": "repertoire_abstraction",
    "base45": "binary_transform",
    "base64codec": "binary_transform",
    "bcdic": "encoding_family",
    "bookshelfsymbol7": "font_identity",
    "braillecode": "writing_system",
    "bz2codec": "compression_transform",
    "cariadings": "font_identity",
    "casiocalculatorcharactersets": "encoding_family",
    "fieldata": "encoding_family",
    "hexcodec": "binary_transform",
    "internationalmaritimesignalflags": "visual_signaling_system",
    "jiskanjicodes": "encoding_family",
    "jisx0211": "control_standard",
    "jisx0213": "repertoire_profile",
    "jisx0221": "encoding_family",
    "jukitoitsumoji": "repertoire_profile",
    "lotusmultibytecharacterset": "encoding_family",
    "marlett": "font_identity",
    "mbcs": "platform_adapter",
    "microsoftstandardjapanesecharacterset": "repertoire_profile",
    "mojijohokibanideographs": "repertoire_profile",
    "q11496598": "repertoire_profile",
    "q65228706": "repertoire_profile",
    "q65274238": "repertoire_profile",
    "quopricodec": "binary_transform",
    "rot13": "text_transform",
    "signwritinginunicode": "unicode_representation_profile",
    "sixbitcharactercode": "encoding_family",
    "swedishascii": "encoding_family",
    "symbol": "font_identity",
    "theunicodestandard": "encoding_family",
    "ticalculatorcharactersets": "encoding_family",
    "unicodeemojivariationsequence": "unicode_sequence_profile",
    "unicodevariationsequence": "unicode_sequence_mechanism",
    "urwdingbats": "font_identity",
    "uucodec": "binary_transform",
    "variablelengthcode": "coding_technique",
    "videotexcharacterset": "encoding_family",
    "webdings": "font_identity",
    "wingdings": "font_identity",
    "wingdings2": "font_identity",
    "wingdings3": "font_identity",
    "yuscii": "encoding_family",
    "zlibcodec": "compression_transform",
}

# Codecs supplied by separate Iconvex external packages rather than GNU
# libiconv-derived core/extra tables.
ICONVEX_EXTERNAL_CODEC_KEYS = {
    "adobestandardencoding",
    "adobesymbolencoding",
    "ansel",
    "aplisoir68",
    "aplisoir682004",
    "bocu1",
    "brf",
    "ccir476",
    "ccitt2",
    "ccittno2",
    "cesu8",
    "gsm0338",
    "gsm03382009",
    "ais6",
    "ais6bit",
    "iturm13716",
    "ita2",
    "ita2s2",
    "ituts2",
    "imapmailboxname",
    "iscii",
    "javamodifiedutf8",
    "mnem",
    "mnemonic",
    "macarabic",
    "macceltic",
    "maccentraleurope",
    "macchinesesimp",
    "macchinesetrad",
    "maccroatian",
    "maccyrillic",
    "macdevanagari",
    "macdingbats",
    "macfarsi",
    "macgaelic",
    "macgreek",
    "macgujarati",
    "macgurmukhi",
    "machebrew",
    "maciceland",
    "macinuit",
    "macjapanese",
    "mackeyboard",
    "mackorean",
    "macroman",
    "macromania",
    "macromanian",
    "macsymbol",
    "macthai",
    "macturkish",
    "marc8",
    "modifiedutf8",
    "scsu",
    "tscii",
    "utf7imap",
    "utfebcdic",
    "xuserdefined",
    "xisciias",
    "xisciibe",
    "xisciide",
    "xisciigu",
    "xisciika",
    "xisciima",
    "xisciior",
    "xisciipa",
    "xisciita",
    "xisciite",
    "xiscii91",
    "zapfdingbatsencoding",
    "cp770",
    "cp771",
    "cp772",
    "cp773",
    "cp774",
    "cwi",
    "ebcdicisfriss",
    "eucjpms",
    "hpgreek8",
    "hproman9",
    "hpthai8",
    "hpturkish8",
    "ibm1004",
    "ibm256",
    "ibm866nav",
    "isiri3342",
    "iso88599e",
    "isoir197",
    "isoir209",
    "iso115481",
    "iso6937",
    "koi8",
    "kps9566",
    "kps95662003",
    "macis",
    "macsami",
    "macuk",
    "mik",
    "navtex",
    "sitor",
    "sitorb",
    "simalphaidentifier",
    "simucs2808182",
    "tbcd",
    "telephonybcd",
    "utf1",
    "isoir178",
    "iso10646utf1",
    "viqr",
    "csviqr",
    "isoir68",
    "isoir231",
    "macoscenteuro",
    "macoschinsimp",
    "macoschintrad",
    "macosdevanaga",
    "iceland",
    "roman",
    "turkish",
    "xmacdingbat",
    "usimalphaidentifier",
    "winsami2",
    "koi7switched",
    "cskoi7switched",
    "shortkoi",
    "koi7n2",
    "vkd",
    "kermitelot927greek",
    "elot927greek",
    "decgreek7upper",
    "xutf32bebom",
    "utf32bebom",
    "xutf32lebom",
    "utf32lebom",
    "xutf16lebom",
    "utf16lebom",
    "ibm259",
    "ibmsymbols",
    "csibmsymbols",
    "jisencoding",
    "csjisencoding",
    "isoir156",
    "isoir162",
    "isoir163",
    "isoir174",
    "isoir175",
    "isoir176",
    "isoir177",
    "isoir190",
    "isoir191",
    "isoir192",
    "isoir193",
    "isoir194",
    "isoir195",
    "isoir196",
    "xms9320213",
    "xms950hkscs",
    "jis7",
    "iso2022localejaversion3",
    "jis8",
    "iso2022localejaversion4",
    "lmbcs1",
    "lmbcs",
    "ibm65025",
    "x11compoundtext",
    "compoundtext",
    "xcompoundtext",
    "cp50930",
    "windows50930",
    "cp50931",
    "windows50931",
    "cp50933",
    "windows50933",
    "cp50935",
    "windows50935",
    "cp50937",
    "windows50937",
    "cp50939",
    "windows50939",
    "xeuropa",
    "cp29001",
    "windows29001",
    "europa",
    "europa3",
    "cp51950",
    "windows51950",
    "xcp50227",
    "cp50227",
    "windows50227",
    "amiga1251",
    "ami1251",
    "csamiga1251",
    "extendedunixcodefixedwidthforjapanese",
    "cseucfixwidjapanese",
    "hpdesktop",
    "cshpdesktop",
    "hplegal",
    "cshplegal",
    "hpmath8",
    "cshpmath8",
    "hppifont",
    "cshppifont",
    "iso88591windows30latin1",
    "cswindows30latin1",
    "iso88591windows31latin1",
    "cswindows31latin1",
    "iso88592windowslatin2",
    "cswindows31latin2",
    "iso88599windowslatin5",
    "cswindows31latin5",
    "microsoftpublishing",
    "csmicrosoftpublishing",
    "pc8danishnorwegian",
    "cspc8danishnorwegian",
    "pc8turkish",
    "cspc8turkish",
    "venturainternational",
    "csventurainternational",
    "venturamath",
    "csventuramath",
    "venturaus",
    "csventuraus",
    "iso10646ucsbasic",
    "csunicodeascii",
    "iso10646unicodelatin1",
    "csunicodelatin1",
    "iso10646",
    "iso10646j1",
    "csunicodejapanese",
    "isoir171",
    "cns116431992plane1",
    "cns116431",
    "isoir172",
    "cns116431992plane2",
    "cns116432",
    "isoir183",
    "cns116431992plane3",
    "cns116433",
    "isoir184",
    "cns116431992plane4",
    "cns116434",
    "isoir185",
    "cns116431992plane5",
    "cns116435",
    "isoir186",
    "cns116431992plane6",
    "cns116436",
    "isoir187",
    "cns116431992plane7",
    "cns116437",
    "isoir228",
    "jisx02132000plane1",
    "isoir229",
    "jisx02132000plane2",
    "jisx02132004plane2",
    "isoir233",
    "jisx02132004plane1",
    "isoir31",
    "greekbibliographic1976",
    "isoir198",
    "latinhebrewisoir198",
    # Exact standards/profile aliases owned by iconvex core. They are kept
    # outside GNU's alias-parity inventory because GNU 1.19 does not expose
    # these spellings.
    "iso88596e",
    "iso88596i",
    "iso88598e",
    "iso88598i",
    "isoir168",
    "isoir180",
    "isoir227",
    "cp1201",
    "windows1201",
    "unicodefffe",
}

# These exact OpenJDK records were removed from the LGPL Specs runtime after a
# provenance audit. A differently owned alias (notably Core's `cp50221`) must
# not make the quarantined OpenJDK canonical record appear implemented.
OPENJDK_QUARANTINED_KEYS = {
    "xeucjpopen",
    "xms950hkscsxp",
    "xwindows50220",
    "xwindows50221",
    "xwindowsiso2022jp",
    "xiso2022cngb",
    "xiso2022cncns",
}

# RFC 1345 codecs implemented by iconvex_specs. These two definitions remain
# catalogued but are deliberately not advertised: the public JIS 1978 table
# lacks Unicode values, while RFC erratum 6067 still has 272 IBM423 cells.
ICONVEX_RFC1345_QUARANTINED_KEYS = {
    "jisc62261978",
    "ibm423",
}


@dataclass
class Record:
    name: str
    aliases: list[str]
    source: str
    source_url: str
    source_id: str = ""
    kind: str = "character_encoding"
    description: str = ""
    status: str = ""
    confidence: str = "high"
    metadata: dict[str, str] = field(default_factory=dict)

    def labels(self) -> list[str]:
        return unique([self.name, *self.aliases])


class Fetcher:
    def __init__(self) -> None:
        self.manifest: dict[str, dict[str, object]] = {}
        self.last_request: dict[str, float] = {}
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def _sleep(seconds: float) -> None:
        remaining = max(0.0, seconds)
        while remaining > 0:
            chunk = min(remaining, 30.0)
            time.sleep(chunk)
            remaining -= chunk

    def _throttle(self, url: str) -> None:
        host = urllib.parse.urlparse(url).netloc.casefold()
        interval = {
            "query.wikidata.org": 61.0,
            "en.wikipedia.org": 1.1,
            "www.wikidata.org": 1.1,
            "www.unicode.org": 0.25,
        }.get(host, 0.15)
        elapsed = time.monotonic() - self.last_request.get(host, 0.0)
        if elapsed < interval:
            self._sleep(interval - elapsed)
        self.last_request[host] = time.monotonic()

    @staticmethod
    def _retry_after(error: urllib.error.HTTPError) -> float | None:
        value = error.headers.get("Retry-After") if error.headers else None
        if not value:
            return None
        value = value.strip()
        if value.isdigit():
            return float(value)
        try:
            retry_at = email.utils.parsedate_to_datetime(value)
            if retry_at.tzinfo is None:
                retry_at = retry_at.replace(tzinfo=timezone.utc)
            return max(0.0, (retry_at - datetime.now(timezone.utc)).total_seconds())
        except (TypeError, ValueError, OverflowError):
            return None

    def bytes(self, url: str, *, accept: str | None = None) -> bytes:
        cache_path = CACHE_DIR / (hashlib.sha256(url.encode("utf-8")).hexdigest() + ".bin")
        if cache_path.exists():
            data = cache_path.read_bytes()
            self.manifest[url] = {
                "final_url": url,
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "content_type": "cached",
                "cached": True,
            }
            return data
        headers = {"User-Agent": USER_AGENT}
        if accept:
            headers["Accept"] = accept
        request = urllib.request.Request(url, headers=headers)
        pending_delay = 0.0
        for attempt in range(6):
            if pending_delay:
                self._sleep(pending_delay)
            self._throttle(url)
            try:
                with urllib.request.urlopen(request, timeout=90) as response:
                    data = response.read()
                    final_url = response.geturl()
                    content_type = response.headers.get("Content-Type", "")
                break
            except urllib.error.HTTPError as error:
                if error.code != 429 and error.code < 500:
                    raise
                if attempt == 5:
                    raise
                retry_after = self._retry_after(error)
                fallback = min(60.0, float(2**attempt))
                if error.code == 429 and urllib.parse.urlparse(url).netloc == "query.wikidata.org":
                    fallback = max(fallback, 61.0)
                pending_delay = max(retry_after or 0.0, fallback)
        else:  # pragma: no cover - loop either succeeds or raises
            raise RuntimeError(f"failed to fetch {url}")
        cache_path.write_bytes(data)
        self.manifest[url] = {
            "final_url": final_url,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "content_type": content_type,
        }
        return data

    def text(self, url: str) -> str:
        return self.bytes(url).decode("utf-8", "replace")

    def json(self, url: str) -> object:
        return json.loads(self.bytes(url, accept="application/json").decode("utf-8"))


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "tr":
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._cell = []
        elif tag == "br" and self._cell is not None:
            self._cell.append(" ")

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"td", "th"} and self._cell is not None and self._row is not None:
            self._row.append(clean_space("".join(self._cell)))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            if self._row:
                self.rows.append(self._row)
            self._row = None


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        href = dict(attrs).get("href")
        if href:
            self.links.append(href)


class UnionFind:
    def __init__(self, size: int) -> None:
        self.parent = list(range(size))

    def find(self, value: int) -> int:
        while self.parent[value] != value:
            self.parent[value] = self.parent[self.parent[value]]
            value = self.parent[value]
        return value

    def union(self, left: int, right: int) -> None:
        left = self.find(left)
        right = self.find(right)
        if left != right:
            self.parent[right] = left


def clean_space(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(value)).strip()


def unique(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        value = clean_space(value)
        if value and value.casefold() not in seen:
            seen.add(value.casefold())
            result.append(value)
    return result


def key(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold()
    return "".join(character for character in value if character.isalnum())


def support_key_variants(value: str) -> set[str]:
    """Return spelling variants used only for implementation coverage checks."""
    normalized = key(value)
    result = {normalized}
    if match := re.fullmatch(r"(?:codepage|windowscodepage)0*(\d+)", normalized):
        result.add(f"cp{int(match.group(1))}")
    for suffix in ("characterset", "characterencoding", "charset"):
        if normalized.endswith(suffix) and len(normalized) > len(suffix):
            result.add(normalized[: -len(suffix)])
    return result


# Property-token mappings are deliberately outside the codec inventories. Their
# implemented disposition must come from the generated Specs API snapshot, not
# merely from a research record's kind label.
PROPERTY_TOKEN_MAPPING_INVENTORY = (
    ROOT.parent / "iconvex_specs/SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv"
)
IMPLEMENTED_PROPERTY_TOKEN_MAPPING_KEYS: set[str] = set()
if PROPERTY_TOKEN_MAPPING_INVENTORY.exists():
    with PROPERTY_TOKEN_MAPPING_INVENTORY.open(newline="") as stream:
        reader = csv.DictReader(stream)
        expected_fields = [
            "mapping_name",
            "module",
            "unicode_property",
            "profile",
            "assigned_tokens",
            "reverse_scalars",
            "grammar",
            "transport",
            "codec_registry",
            "gnu_libiconv_1_19_exact_alias",
        ]
        if reader.fieldnames != expected_fields:
            raise RuntimeError("unexpected property-token mapping inventory schema")
        IMPLEMENTED_PROPERTY_TOKEN_MAPPING_KEYS.update(
            key(row["mapping_name"]) for row in reader
        )


# Exact ICU revision names are generated and audited by the sibling
# iconvex_specs package. Loading their generated matrices avoids duplicating a
# 175-name revision inventory in this research script while keeping standalone
# catalog generation functional when that package is absent.
for support_matrix in (
    ROOT.parent / "iconvex_specs/ICU_UCM_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/ICU_MULTIBYTE_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/ICU_EBCDIC_STATEFUL_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/ICU_SWAP_LFNL_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/ICU_UNICODE_VARIANTS.md",
    ROOT.parent / "iconvex_specs/WINDOWS_BEST_FIT_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/UNICODE_LEGACY_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/ISO_IR_MODERN_ENCODINGS.md",
    ROOT.parent / "iconvex_specs/UNICODE_MAPPING_COMPONENTS.md",
    ROOT.parent / "iconvex_specs/IANA_PCL_SYMBOL_SETS.md",
    ROOT.parent / "iconvex_specs/IANA_ISO10646_PROFILES.md",
    ROOT.parent / "iconvex_specs/IBM_UNICODE_CCSIDS.md",
    ROOT.parent / "iconvex_specs/ISO_IR_CNS11643.md",
    ROOT.parent / "iconvex_specs/ISO_IR_JISX0213.md",
    ROOT.parent / "iconvex_specs/ISO_IR_HISTORICAL_GRAPHIC.md",
    ROOT.parent / "iconvex_specs/ISO_IR_MOSAIC_TECHNICAL.md",
    ROOT.parent / "iconvex_specs/KPS9566_97.md",
    ROOT.parent / "iconvex_specs/LEGACY_COMPUTING_N5028.md",
):
    if support_matrix.exists():
        text = support_matrix.read_text()
        names = re.findall(r"^\| `([^`]+)` \|", text, re.MULTILINE)
        ICONVEX_EXTERNAL_CODEC_KEYS.update(key(name) for name in names)

        # Only matrices whose second column is explicitly named Aliases may
        # contribute second-column spellings. Standard/source columns often
        # contain code-formatted identifiers too and are not runtime aliases.
        if re.search(r"^\| (?:Encoding|Canonical) \| Aliases \|", text, re.MULTILINE):
            for alias_cell in re.findall(r"^\| `[^`]+` \| (.*?) \|", text, re.MULTILINE):
                aliases = re.findall(r"`([^`]+)`", alias_cell)
                ICONVEX_EXTERNAL_CODEC_KEYS.update(key(alias) for alias in aliases)

        for name in names:
            if match := re.fullmatch(r"WINDOWS-BESTFIT-(\d+)", name, re.IGNORECASE):
                ICONVEX_EXTERNAL_CODEC_KEYS.add(key("bestfit" + match.group(1)))

# These single-codec conformance reports use property tables rather than a
# conventional Encoding column, so declare their exact runtime aliases here.
ICONVEX_EXTERNAL_CODEC_KEYS.update({"isoir42", "isoir169", "blissymbolicsisoir169"})

archive_matrix = ROOT.parent / "iconvex_specs/ICU_ARCHIVE_ENCODINGS.md"
if archive_matrix.exists():
    for canonical, code_set_name in re.findall(
        r"^\| `([^`]+)` \| `([^`]+)` \|", archive_matrix.read_text(), re.MULTILINE
    ):
        labels = [canonical, code_set_name]
        ICONVEX_EXTERNAL_CODEC_KEYS.update(key(label) for label in labels)

        # Historical UCM revision names preserve vendor/version suffixes. A
        # catalog record such as IBM-1364 or x-IBM1364 is still covered by an
        # exact `ibm-1364_P...` revision even when that short name is too
        # ambiguous to register as a runtime alias.
        for label in labels:
            stripped = re.sub(r"(?i)^(?:ICU-ARCHIVE-|java-|glibc-)", "", label)
            stripped = re.sub(r"(?i)-\d+(?:\.\d+)*(?:_[A-Z])?(?:\.ucm)?$", "", stripped)
            ICONVEX_EXTERNAL_CODEC_KEYS.add(key(stripped))

            match = re.search(r"(?i)(?:ibm|cp|windows)[_-]?0*(\d{2,5})", label)
            if match:
                number = match.group(1)
                ICONVEX_EXTERNAL_CODEC_KEYS.update(
                    key(prefix + number)
                    for prefix in ("IBM", "CP", "CCSID", "x-IBM", "windows-")
                )

# External packages publish checked-in CSVs generated from live codec modules.
# Consuming those snapshots makes research-gap classification follow the exact
# public runtime inventory rather than hand-maintained documentation tables.
for external_inventory in (
    ROOT.parent / "iconvex_extras/SUPPORTED_CODEC_INVENTORY.csv",
    ROOT.parent / "iconvex_specs/SUPPORTED_CODEC_INVENTORY.csv",
    ROOT.parent / "iconvex_specs/SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv",
    ROOT.parent / "iconvex_specs/SUPPORTED_RAW_TRANSPORT_INVENTORY.csv",
    ROOT.parent / "iconvex_telecom/SUPPORTED_CODEC_INVENTORY.csv",
):
    if external_inventory.exists():
        with external_inventory.open(newline="") as stream:
            for row in csv.DictReader(stream):
                labels = [row["canonical"], *row.get("aliases", "").split("|")]
                ICONVEX_EXTERNAL_CODEC_KEYS.update(key(label) for label in labels if label)

core_name_inventory = ROOT / "SUPPORTED_NAME_INVENTORY.csv"
if core_name_inventory.exists():
    with core_name_inventory.open(newline="") as stream:
        for row in csv.DictReader(stream):
            ICONVEX_EXTERNAL_CODEC_KEYS.update(key(row[field]) for field in ("name", "canonical"))

# `x-` is widely used for non-IANA vendor aliases. It does not denote a
# different mapping, so recognize it when classifying already-implemented
# external codecs without adding a potentially ambiguous runtime alias.
ICONVEX_EXTERNAL_CODEC_KEYS.update("x" + value for value in list(ICONVEX_EXTERNAL_CODEC_KEYS))

# The RFC matrix is the authoritative generated completeness decision. Feed its
# canonical names and aliases back into research support classification so ISO-IR
# records with long descriptive titles are not reported as missing merely because
# alias edges are intentionally non-transitive in the catalog merger.
specs_matrix = ROOT.parent / "iconvex_specs/SUPPORTED_ENCODINGS.md"
if specs_matrix.exists():
    rfc_section = specs_matrix.read_text().split("## RFC 1345 coded character sets", 1)[-1]
    for line in rfc_section.splitlines():
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) == 6 and cells[-1] == "complete" and cells[0].startswith("`"):
            canonical = cells[0].strip("`")
            aliases = [alias.strip() for alias in cells[1].split(",") if alias.strip()]
            ICONVEX_EXTERNAL_CODEC_KEYS.update(key(name) for name in [canonical, *aliases])


def parse_iana(fetcher: Fetcher) -> list[Record]:
    rows = csv.DictReader(io.StringIO(fetcher.text(IANA_URL)))
    records: list[Record] = []
    for row in rows:
        preferred = row["Preferred MIME Name"].strip()
        registered = row["Name"].strip()
        aliases = [line.strip() for line in row["Aliases"].splitlines() if line.strip()]
        name = preferred or registered
        records.append(
            Record(
                name,
                unique([registered, *aliases]),
                "iana",
                "https://www.iana.org/assignments/character-sets/character-sets.xhtml",
                f"MIBenum {row['MIBenum']}",
                "iana_registered_charset",
                clean_space(row["Source"]),
            )
        )
    return records


def parse_whatwg(fetcher: Fetcher) -> list[Record]:
    groups = fetcher.json(WHATWG_URL)
    records: list[Record] = []
    for group in groups:
        for encoding in group["encodings"]:
            name = encoding["name"]
            kind = "web_pseudo_encoding" if name == "replacement" else "web_encoding"
            records.append(
                Record(
                    name,
                    encoding["labels"],
                    "whatwg",
                    "https://encoding.spec.whatwg.org/",
                    group["heading"],
                    kind,
                )
            )
    return records


def parse_icu(fetcher: Fetcher) -> list[Record]:
    source = fetcher.text(ICU_URL)
    records: list[Record] = []
    logical: list[str] = []
    current = ""
    started = False
    for physical in source.splitlines():
        line = physical.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if not physical[:1].isspace():
            if current:
                logical.append(current)
            current = line.strip()
            if re.match(r"^[A-Za-z0-9]", current):
                started = True
        elif started and current:
            current += " " + line.strip()
    if current:
        logical.append(current)
    for line in logical:
        if line.startswith("{"):
            continue
        without_tags = re.sub(r"\{[^}]*\}", " ", line)
        tokens = without_tags.split()
        if not tokens:
            continue
        records.append(
            Record(
                tokens[0],
                tokens[1:],
                "icu",
                ICU_URL,
                tokens[0],
                "icu_converter",
                confidence="high",
            )
        )
    return records


def parse_glibc(fetcher: Fetcher) -> list[Record]:
    aliases_by_name: defaultdict[str, list[str]] = defaultdict(list)
    canonical_names: set[str] = set()
    for url in GLIBC_URLS:
        for raw_line in fetcher.text(url).splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            fields = line.split()
            if fields[0] == "alias" and len(fields) >= 3:
                alias = fields[1].removesuffix("//")
                canonical = fields[2].removesuffix("//")
                aliases_by_name[canonical].append(alias)
            elif fields[0] == "module" and len(fields) >= 4:
                source = fields[1].removesuffix("//")
                target = fields[2].removesuffix("//")
                for name in (source, target):
                    if name not in {"INTERNAL", ""} and not any(character in name for character in "[]()\\"):
                        canonical_names.add(name)
    canonical_names.update(aliases_by_name)
    return [
        Record(
            name,
            aliases_by_name[name],
            "glibc",
            "https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html",
            name,
            "glibc_gconv_codec",
            status="glibc_current_source",
        )
        for name in sorted(canonical_names, key=str.casefold)
    ]


def parse_openjdk(fetcher: Fetcher) -> list[Record]:
    source = fetcher.text(OPENJDK_CHARSETS_URL)
    starts = list(re.finditer(r"^charset\s+(\S+)\s+(\S+)\s*$", source, re.MULTILINE))
    records: list[Record] = []
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(source)
        block = source[match.end() : end]
        aliases = re.findall(r"^\s+alias\s+(\S+)", block, re.MULTILINE)
        package = re.search(r"^\s+package\s+(\S+)", block, re.MULTILINE)
        internal = bool(re.search(r"^\s+internal\s+true(?:\s|$)", block, re.MULTILINE))
        records.append(
            Record(
                match.group(1),
                aliases,
                "openjdk",
                OPENJDK_CHARSETS_URL,
                match.group(2),
                "openjdk_internal_component" if internal else "openjdk_charset",
                (
                    "OpenJDK marks this declaration `internal true`; it is a mapping or "
                    "encoder implementation component, not a public Charset."
                    if internal
                    else ""
                ),
                status="openjdk_internal" if internal else "openjdk_current_source",
                confidence="candidate" if internal else "high",
                metadata={
                    "package": package.group(1) if package else "",
                    "internal": "true" if internal else "false",
                },
            )
        )
    return records


def parse_python(fetcher: Fetcher) -> list[Record]:
    source = fetcher.text(PYTHON_ALIASES_URL)
    tree = ast.parse(source)
    aliases: dict[str, str] = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "aliases" for target in node.targets
        ):
            aliases = ast.literal_eval(node.value)
            break
    grouped: defaultdict[str, list[str]] = defaultdict(list)
    for alias, canonical in aliases.items():
        grouped[canonical].append(alias)

    # Add codec modules absent from aliases.py, excluding infrastructure modules.
    infrastructure = {
        "__init__",
        "aliases",
        "charmap",
        "idna",
        "mbcs",
        "oem",
        "palmos",
        "punycode",
        "raw_unicode_escape",
        "rot_13",
        "undefined",
        "unicode_escape",
        "unicode_internal",
    }
    listing = fetcher.json(PYTHON_ENCODINGS_API)
    for item in listing:
        name = item.get("name", "")
        if name.endswith(".py"):
            module = name[:-3]
            if module not in infrastructure and not module.startswith("_"):
                grouped.setdefault(module, [])
    return [
        Record(
            canonical.replace("_", "-"),
            [alias.replace("_", "-") for alias in names],
            "python",
            "https://docs.python.org/3/library/codecs.html#standard-encodings",
            canonical,
            "python_codec",
            confidence="medium",
        )
        for canonical, names in grouped.items()
    ]


def parse_html_table(text: str) -> list[list[str]]:
    parser = TableParser()
    parser.feed(text)
    return parser.rows


def parse_microsoft(fetcher: Fetcher) -> list[Record]:
    records: list[Record] = []
    for row in parse_html_table(fetcher.text(MICROSOFT_URL)):
        if len(row) < 3 or not re.fullmatch(r"\d+", row[0]):
            continue
        number = str(int(row[0]))
        dotnet = row[1]
        name = dotnet or f"Windows code page {number}"
        aliases = [f"CP{number}", f"windows-{number}"]
        if dotnet:
            aliases.append(dotnet)
        records.append(
            Record(
                name,
                aliases,
                "microsoft",
                MICROSOFT_URL,
                f"CP {number}",
                "microsoft_code_page",
                row[2],
            )
        )
    return records


def parse_ibm(fetcher: Fetcher) -> list[Record]:
    records: list[Record] = []
    for row in parse_html_table(fetcher.text(IBM_I_URL)):
        if len(row) < 3 or not re.fullmatch(r"\d{5}", row[0]):
            continue
        number = str(int(row[0]))
        records.append(
            Record(
                f"IBM-{number}",
                [f"IBM{number}", f"CCSID{number}", f"CP{number}"],
                "ibm_i",
                IBM_I_URL,
                f"CCSID {number}",
                "ibm_ccsid",
                row[2],
                metadata={"ibm_encoding_scheme": row[1]},
            )
        )
    return records


def parse_rfc1345(fetcher: Fetcher) -> list[Record]:
    source = fetcher.text(RFC1345_URL)
    matches = list(re.finditer(r"^\s*&charset\s+(\S+)\s*$", source, re.MULTILINE))
    records: list[Record] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(source)
        block = source[match.end() : end]
        aliases = re.findall(r"^\s*&alias\s+(\S+)\s*$", block, re.MULTILINE)
        records.append(
            Record(
                match.group(1),
                aliases,
                "rfc1345",
                "https://www.rfc-editor.org/rfc/rfc1345.html",
                match.group(1),
                "rfc1345_charset",
                status="historical_registry",
            )
        )
    return records


def parse_kermit(fetcher: Fetcher) -> list[Record]:
    source = fetcher.text(KERMIT_URL)
    text = html.unescape(re.sub(r"<[^>]+>", "", source))
    kind_map = {
        "A": "ascii",
        "7": "national_replacement_set",
        "S": "standard_8bit_set",
        "8": "vendor_8bit_set",
        "P": "pc_code_page",
        "W": "windows_code_page",
        "B": "terminal_glyph_set",
        "M": "multibyte_encoding",
        "U": "unicode_encoding",
    }
    records: list[Record] = []
    pattern = re.compile(r"^\s*(?:X|\s){4,}\s+([A78PSWBMU])\s+(\S+)\s+(.+?)\s*$")
    for line in text.splitlines():
        match = pattern.match(line)
        if not match:
            continue
        type_code, name, description = match.groups()
        records.append(
            Record(
                name,
                [],
                "kermit",
                KERMIT_URL,
                name,
                kind_map[type_code],
                description,
                status="legacy_implementation",
                confidence="medium",
            )
        )
    return records


def normalize_iso_ir_number(value: str) -> str:
    return "-".join(str(int(piece)) for piece in value.split("-"))


def parse_iso_ir(fetcher: Fetcher) -> list[Record]:
    try:
        from pypdf import PdfReader
    except ImportError as error:
        raise RuntimeError("pypdf required for ISO-IR registry extraction") from error

    pdf = fetcher.bytes(ISO_IR_ARCHIVE_URL)
    reader = PdfReader(io.BytesIO(pdf))
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    lines = [clean_space(line) for line in text.splitlines()]
    sections: list[str] = [""] * len(lines)
    current = ""
    for index, line in enumerate(lines):
        heading = re.match(r"^(2\.\d+(?:\.\d+)?)\b", line)
        if heading:
            current = heading.group(1)
        sections[index] = current

    allowed = {"2.1", "2.2", "2.3", "2.4", "2.8", "2.8.1", "2.8.2"}
    records: list[Record] = []
    for index, line in enumerate(lines):
        match = re.search(r"https://itscj\.ipsj\.or\.jp/ir/([0-9-]+)\.pdf", line)
        if not match or sections[index] not in allowed:
            continue
        raw_number = match.group(1)
        number = normalize_iso_ir_number(raw_number)
        start = None
        inline = ""
        for candidate in range(index - 1, max(-1, index - 16), -1):
            number_match = re.match(r"^(\d+(?:-\d+)?)\s*(.*)$", lines[candidate])
            if number_match and normalize_iso_ir_number(number_match.group(1)) == number:
                start = candidate
                inline = number_match.group(2)
                break
        if start is None:
            continue
        description_lines = [inline] if inline else []
        for candidate in range(start + 1, index):
            value = lines[candidate]
            if not value or value.startswith("=====") or value.startswith("https://"):
                continue
            if re.match(r"^\d/\d(?:\s|$)", value):
                continue
            description_lines.append(value)
        description = clean_space(" ".join(description_lines))
        section = sections[index]
        kind = "iso_ir_coding_system" if section.startswith("2.8") else "iso_ir_coded_character_set"
        records.append(
            Record(
                description or f"ISO-IR-{number}",
                [f"ISO-IR-{number}"],
                "iso_ir",
                f"https://itscj.ipsj.or.jp/ir/{raw_number}.pdf",
                f"ISO-IR-{number}",
                kind,
                description,
                status="registered_historical",
                metadata={"iso_ir_section": section},
            )
        )
    return records


def parse_unicode_mappings(fetcher: Fetcher) -> list[Record]:
    records: list[Record] = []
    for root in UNICODE_MAPPING_ROOTS:
        queue = deque([root])
        visited: set[str] = set()
        while queue:
            url = queue.popleft()
            if url in visited:
                continue
            visited.add(url)
            parser = LinkParser()
            parser.feed(fetcher.text(url))
            for href in parser.links:
                if href.startswith(("?", "/", "../")):
                    continue
                child = urllib.parse.urljoin(url, href)
                if href.endswith("/"):
                    queue.append(child)
                    continue
                if not href.lower().endswith((".txt", ".ucm")) or "readme" in href.casefold():
                    continue
                stem = Path(urllib.parse.urlparse(child).path).stem
                path_parts = urllib.parse.urlparse(child).path.split("/")
                vendor = path_parts[path_parts.index("VENDORS") + 1] if "VENDORS" in path_parts else "OBSOLETE"
                if vendor == "APPLE":
                    name = f"Mac OS {stem.replace('_', ' ').title()}"
                    aliases = [f"Mac{stem.replace('_', '')}"]
                elif vendor == "ADOBE":
                    adobe = {
                        "stdenc": "Adobe Standard Encoding",
                        "symbol": "Adobe Symbol Encoding",
                        "zdingbat": "Zapf Dingbats Encoding",
                    }
                    name = adobe.get(stem.casefold(), f"Adobe {stem}")
                    aliases = []
                elif re.fullmatch(r"(?i)(?:cp|ibm)\d+", stem):
                    name = stem.upper()
                    aliases = []
                elif vendor == "NEXT":
                    name = "NEXTSTEP" if stem.casefold() == "nextstep" else stem
                    aliases = []
                else:
                    name = stem.replace("_", "-")
                    aliases = []
                component_kinds = {
                    "corpchar": "unicode_character_registry_component",
                    "sgml": "sgml_entity_mapping",
                }
                records.append(
                    Record(
                        name,
                        aliases,
                        "unicode_mappings",
                        child,
                        f"{vendor}/{stem}",
                        component_kinds.get(stem.casefold(), "unicode_mapping_table"),
                        status="mapping_archive",
                    )
                )
    return records


def parse_wikidata(fetcher: Fetcher) -> list[Record]:
    query = """
SELECT DISTINCT ?item ?itemLabel ?itemDescription ?class ?classLabel WHERE {
  ?item wdt:P31 ?class.
  ?class wdt:P279* wd:Q184759.
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
""".strip()
    url = WIKIDATA_ENDPOINT + "?format=json&query=" + urllib.parse.quote(query)
    result = fetcher.json(url)
    records: list[Record] = []
    seen: set[tuple[str, str]] = set()
    for binding in result["results"]["bindings"]:
        item = binding["item"]["value"]
        qid = item.rsplit("/", 1)[-1]
        name = binding.get("itemLabel", {}).get("value", qid)
        if name == qid:
            name = AUDITED_WIKIDATA_FALLBACK_LABELS.get(qid, qid)
        class_name = binding.get("classLabel", {}).get("value", "character encoding")
        marker = (qid, class_name)
        if marker in seen:
            continue
        seen.add(marker)
        records.append(
            Record(
                name,
                [],
                "wikidata",
                f"https://www.wikidata.org/wiki/{qid}",
                qid,
                "wikidata_" + key(class_name),
                binding.get("itemDescription", {}).get("value", ""),
                confidence="medium",
            )
        )
    return records


def wikipedia_category(fetcher: Fetcher, title: str) -> tuple[list[dict[str, object]], list[str]]:
    members: list[dict[str, object]] = []
    continuation = ""
    while True:
        params = {
            "action": "query",
            "list": "categorymembers",
            "cmtitle": "Category:" + title,
            "cmlimit": "max",
            "format": "json",
        }
        if continuation:
            params["cmcontinue"] = continuation
        url = WIKIPEDIA_API + "?" + urllib.parse.urlencode(params)
        result = fetcher.json(url)
        time.sleep(0.3)
        members.extend(result.get("query", {}).get("categorymembers", []))
        continuation = result.get("continue", {}).get("cmcontinue", "")
        if not continuation:
            break
    pages = [member for member in members if member.get("ns") == 0]
    categories = [
        str(member["title"]).removeprefix("Category:")
        for member in members
        if member.get("ns") == 14
    ]
    return pages, categories


def parse_wikipedia(fetcher: Fetcher) -> list[Record]:
    roots = ["Character sets", "Unicode Transformation Formats"]
    recurse_into = {
        "Encodings of Asian languages",
        "Calculator character sets",
        "Chinese character encodings",
        "Classic Mac OS character encodings",
        "DOS code pages",
        "EBCDIC code pages",
        "IBM AIX code pages",
        "ISO/IEC 8859",
        "Windows code pages",
    }
    queue = deque((root, 0) for root in roots)
    visited: set[str] = set()
    pages: dict[int, str] = {}
    while queue:
        category, depth = queue.popleft()
        if category in visited:
            continue
        visited.add(category)
        category_pages, subcategories = wikipedia_category(fetcher, category.replace(" ", "_"))
        for page in category_pages:
            pages[int(page["pageid"])] = str(page["title"])
        if depth < 1:
            queue.extend(
                (subcategory, depth + 1)
                for subcategory in subcategories
                if subcategory in recurse_into
            )

    records: list[Record] = []
    excluded = re.compile(
        r"^(?:Character encoding|Character set|Code page|Comparison of|History of|List of|Template)",
        re.IGNORECASE,
    )
    for page_id, title in pages.items():
        if excluded.match(title) and not re.match(r"^Code page \d", title, re.IGNORECASE):
            continue
        article = "https://en.wikipedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_"))
        aliases: list[str] = []
        qualifier = re.match(r"^(.*?) \((?:Unicode|character encoding|encoding)\)$", title)
        if qualifier:
            aliases.append(qualifier.group(1))
        records.append(
            Record(
                title,
                aliases,
                "wikipedia",
                article,
                f"pageid {page_id}",
                "wikipedia_character_set_page",
                confidence="candidate",
            )
        )
    return records


def parse_wikipedia_historical(fetcher: Fetcher) -> list[Record]:
    records: list[Record] = []
    seen: set[str] = set()
    for row in parse_html_table(fetcher.text(WIKIPEDIA_HISTORICAL_URL)):
        if len(row) < 4 or row[0].casefold() == "code":
            continue
        name = clean_space(re.sub(r"\[\d+\]", "", row[0]))
        if not name or name.casefold() in seen:
            continue
        seen.add(name.casefold())
        description = f"Introduced {row[1]}; width {row[2]}; {row[3]}"
        if name == "Transcode":
            description = (
                "Introduced 1967; IBM primary manuals define six-bit code units "
                "transmitted low-order-bit first. Their displayed parity column is not "
                "a seventh wire bit, and exact device profiles differ at unit 0x0C."
            )

        records.append(
            Record(
                name,
                [],
                "wikipedia_historical",
                WIKIPEDIA_HISTORICAL_URL,
                name,
                "historical_information_system_encoding",
                description,
                status="historical_inventory",
                confidence="medium",
            )
        )
    return records


def parse_punched_card_codes(fetcher: Fetcher) -> list[Record]:
    source = html.unescape(fetcher.text(PUNCHED_CARD_CODES_URL))
    inventory = [
        (
            "Hollerith consensus punched-card code",
            ["Hollerith card code", "consensus code"],
            "The Main Line of Development, from BCD to EBCDIC",
        ),
        ("IBM 026 Commercial card code", ["BCD-A"], "026 commercial character set"),
        ("IBM 026 FORTRAN card code", ["BCD-H"], "026 FORTRAN character set"),
        ("IBM H code (report-writing)", ["IBM 7040 report code"], "REPT &-0123456789"),
        ("IBM H code (programming)", ["IBM 7040 programming code"], "PROG +-0123456789"),
        ("IBM 1401 card code", [], "1401 &-0123456789"),
        ("IBM 029 card code", [], "The IBM model 029 keypunch"),
        ("IBMEL card character set", ["IBMEL"], "IBMEL character set"),
        ("EBCD card character set", ["EBCD"], "EBCD and IBMEL character sets"),
        ("CDC punched-card BCD", ["BCD-CDC"], "BCD-CDC character set"),
        ("DEC 026 card code", [], "DEC 026 code"),
        ("DEC 029 card code", [], "DEC 029 code"),
        ("GE 600 punched-card code", ["GE card code"], "including the GE 600"),
        ("UNIVAC 1108 punched-card code", [], "UNIVAC 1108 version"),
    ]
    records: list[Record] = []
    for name, aliases, marker in inventory:
        if marker not in source:
            raise RuntimeError(f"punched-card inventory marker disappeared: {marker}")
        records.append(
            Record(
                name,
                aliases,
                "punched_cards",
                PUNCHED_CARD_CODES_URL,
                name,
                "historical_punched_card_encoding",
                status="historical_inventory",
                confidence="medium",
            )
        )
    return records


def parse_gnu_local() -> list[Record]:
    names = (
        "encodings.def",
        "encodings_extra.def",
        "encodings_aix.def",
        "encodings_dos.def",
        "encodings_osf1.def",
        "encodings_zos.def",
        "encodings_local.def",
    )
    by_id: dict[str, dict[str, object]] = {}
    for filename in names:
        path = ROOT / "test/fixtures/gnu-libiconv-1.19-encodings" / filename
        source = re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.DOTALL)
        for names_source, codec_id in re.findall(
            r"DEFENCODING\(\(\s*(.*?)\),\s*([a-z0-9_]+)\s*,", source, re.DOTALL
        ):
            labels = re.findall(r'"([^"]+)"', names_source)
            if not labels:
                continue
            by_id.setdefault(
                codec_id,
                {
                    "canonical": labels[0],
                    "aliases": [],
                    "origin": filename,
                },
            )
            by_id[codec_id]["aliases"] = unique([*by_id[codec_id]["aliases"], *labels])
        for alias, codec_id in re.findall(
            r'DEFALIAS\(\s*"([^"]+)"\s*,\s*([a-z0-9_]+)\s*\)', source, re.DOTALL
        ):
            if codec_id in by_id:
                by_id[codec_id]["aliases"] = unique([*by_id[codec_id]["aliases"], alias])

    records: list[Record] = []
    for codec_id, entry in by_id.items():
        adapter = entry["origin"] == "encodings_local.def"
        records.append(
            Record(
                str(entry["canonical"]),
                list(entry["aliases"]),
                "gnu_libiconv",
                GNU_URL,
                codec_id,
                "locale_abi_adapter" if adapter else "gnu_fixed_codec",
                status="adapter" if adapter else "fixed_codec",
                metadata={"gnu_origin": str(entry["origin"])},
            )
        )
    return records


def supplemental_records() -> list[Record]:
    # Explicitly named formats easily missed by registries/category membership.
    rows = [
        (
            "US-ASCII",
            ["Q8815"],
            "ascii_standard",
            "https://www.rfc-editor.org/rfc/rfc20.html",
            "The exact seven-bit American Standard Code for Information Interchange identity referenced by Wikidata Q8815.",
            "standards_track_rfc",
            "high",
        ),
        (
            "WTF-8",
            ["Wobbly Transformation Format 8"],
            "unicode_compatibility_encoding",
            "https://simonsapin.github.io/wtf-8/",
            "Permits unpaired UTF-16 surrogates; not valid UTF-8.",
            "specification",
            "medium",
        ),
        (
            "Modified UTF-8",
            ["Java Modified UTF-8", "MUTF-8"],
            "unicode_compatibility_encoding",
            "https://docs.oracle.com/javase/8/docs/api/java/io/DataInput.html#modified-utf-8",
            "Java data-stream variant of UTF-8/CESU-8.",
            "vendor_specification",
            "medium",
        ),
        (
            "Punycode",
            ["RFC3492", "RFC-3492", "Bootstring Punycode"],
            "unicode_ascii_transform",
            "https://www.rfc-editor.org/rfc/rfc3492.html",
            "The RFC 3492 Bootstring profile for reversible Unicode-to-ASCII strings; distinct from IDNA processing and its xn-- prefix.",
            "standards_track_rfc",
            "high",
        ),
        (
            "UTF-5",
            ["UTF5", "DRAFT-JSENG-UTF5-01"],
            "unicode_alphanumeric_transform",
            "https://www.ietf.org/archive/id/draft-jseng-utf5-01.txt",
            "The exact uppercase alphanumeric quintet transform defined by draft-jseng-utf5-01, restricted by the native runtime to modern Unicode scalar values.",
            "internet_draft_exact_algorithm",
            "high",
        ),
        (
            "UTF-6",
            ["UTF6", "DRAFT-IETF-IDN-UTF6-00"],
            "unicode_ascii_compatible_hostname_transform",
            "https://www.ietf.org/archive/id/draft-ietf-idn-utf6-00.txt",
            "The exact whole-hostname UTF-16-unit transform defined by draft-ietf-idn-utf6-00, including Y/Z compression, DNS label validation, and surrogate-pair reconstruction.",
            "internet_draft_exact_algorithm",
            "high",
        ),
        (
            "IBM-310-293-P100-COMPOSITE-VPUA",
            [
                "IBM310-293-P100-COMPOSITE-VPUA",
                "CP310-293-P100-COMPOSITE-VPUA",
                "IBM-310-293-P100-VPUA",
            ],
            "versioned_single_byte_composite_profile",
            "https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP00310.txt",
            "Explicit CP310 GCGID interoperability join with the pinned IBM-293 P100 VPUA mapping; deliberately not a generic CP310 identity.",
            "primary_vendor_registry_composite",
            "high",
        ),
        (
            "IBM-TNZ-CP310-B1EAE3C",
            [
                "IBM-TNZ-CP310-07D60F4",
                "TNZ-CP310-B1EAE3C",
                "TNZ-CP310-07D60F4",
                "CP310-TNZ-07D60F4",
            ],
            "versioned_single_byte_vendor_profile",
            "https://github.com/IBM/tnz/blob/b1eae3c8200188b77aceb40754bf89ccbf7646a4/tnz/cp310.py",
            "Byte-exact CP310 table from IBM/tnz commit b1eae3c and blob 07d60f4; deliberately not a generic CP310 identity.",
            "pinned_vendor_revision",
            "high",
        ),
        (
            "IBM-907-CDRA-P100-VPUA-COMPOSITE",
            [
                "IBM907-CDRA-P100-VPUA-COMPOSITE",
                "CP907-CDRA-P100-VPUA-COMPOSITE",
                "IBM-907-P100-VPUA-COMPOSITE",
            ],
            "versioned_single_byte_composite_profile",
            "https://web.archive.org/web/20170803005351id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp00907z.pdf",
            "Explicit IBM CP907 CDRA GCGID/P100 VPUA interoperability profile; deliberately not a generic CP907 identity.",
            "archived_primary_vendor_composite",
            "high",
        ),
        (
            "IBM-1116-850-P100-COMPOSITE",
            [
                "IBM1116-850-P100-COMPOSITE",
                "CP1116-850-P100-COMPOSITE",
                "IBM-1116-P100-COMPOSITE",
            ],
            "versioned_single_byte_composite_profile",
            "https://web.archive.org/web/20130121105553id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp01116z.pdf",
            "Explicit IBM CP1116 GCGID interoperability profile using IBM-850 P100; deliberately not a generic CP1116 identity.",
            "archived_primary_vendor_composite",
            "high",
        ),
        (
            "IBM-1117-437-P100-COMPOSITE",
            [
                "IBM1117-437-P100-COMPOSITE",
                "CP1117-437-P100-COMPOSITE",
                "IBM-1117-P100-COMPOSITE",
            ],
            "versioned_single_byte_composite_profile",
            "https://web.archive.org/web/20130121105553id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp01117z.pdf",
            "Explicit IBM CP1117 GCGID interoperability profile using IBM-437 P100; deliberately not a generic CP1117 identity.",
            "archived_primary_vendor_composite",
            "high",
        ),
        (
            "DEC-GREEK-8-1994",
            [
                "DEC-GREEK-8",
                "DEC-GREEK-8-BIT",
                "DEC-GREEK",
                "EL8DEC",
                "IBM-1287",
                "IBM1287",
                "CP1287",
                "CCSID1287",
            ],
            "versioned_single_byte_character_encoding",
            "https://www.filibeto.org/dec/mds/mds-2000-01/cd3/PRINTER/PPLV2PMB.PDF",
            "DEC Greek 8-bit character set from the revised August 1994 DEC Programming Reference Manual.",
            "primary_vendor_manual",
            "high",
        ),
        (
            "DEC-TURKISH-8-1994",
            [
                "DEC-TURKISH-8",
                "DEC-TURKISH-8-BIT",
                "DEC-TURKISH",
                "TR8DEC",
                "IBM-1288",
                "IBM1288",
                "CP1288",
                "CCSID1288",
            ],
            "versioned_single_byte_character_encoding",
            "https://www.filibeto.org/dec/mds/mds-2000-01/cd3/PRINTER/PPLV2PMB.PDF",
            "DEC Turkish 8-bit character set from the revised August 1994 DEC Programming Reference Manual.",
            "primary_vendor_manual",
            "high",
        ),
        (
            "IBM-7040-H-REPORT",
            ["IBM H code (report-writing)", "IBM 7040 report code"],
            "punched_card_encoding",
            "https://bitsavers.org/pdf/ibm/7040/22-6732-1_7040StudentText.pdf",
            "The 64-character report-writing H-code profile in IBM 7040/7044 Student Text Figure 23.",
            "primary_historical_manual",
            "high",
        ),
        (
            "IBM-7040-H-PROGRAM",
            ["IBM H code (programming)", "IBM 7040 programming code"],
            "punched_card_encoding",
            "https://bitsavers.org/pdf/ibm/7040/22-6732-1_7040StudentText.pdf",
            "The distinct 64-character programming-language H-code profile in IBM 7040/7044 Student Text Figure 23.",
            "primary_historical_manual",
            "high",
        ),
        (
            "IBM-1401-CARD",
            ["IBM 1401 card code"],
            "punched_card_encoding",
            "https://www.bitsavers.org/pdf/ibm/1401/A24-1403-5_1401_Reference_Apr62.pdf",
            "The strict 63-character card-code baseline in IBM 1401 Reference Manual Figure 267.",
            "primary_historical_manual",
            "high",
        ),
        (
            "CDC-167-BCD-HOLLERITH-1965",
            ["CDC 167-2 BCD Hollerith", "CDC 166-series BCD Hollerith"],
            "punched_card_encoding",
            "https://www.bitsavers.org/pdf/cdc/160/options/60022000D_167-2_Card_Reader_Reference_196502.pdf",
            "The 63-character 166-series/167-2 BCD-to-Hollerith translator profile documented in 1965.",
            "primary_historical_manual",
            "high",
        ),
        (
            "CDC-6000-STANDARD-HOLLERITH-1970",
            ["CDC 6000 Standard Hollerith 1970"],
            "punched_card_encoding",
            "https://bitsavers.org/pdf/cdc/graphics/44616800-03_Interactive_Graphics_System_Prelim_Ref_197001.pdf",
            "The 63-character Standard 6000 Hollerith profile and its two documented alternate punches.",
            "primary_historical_manual",
            "high",
        ),
        (
            "CDC punched-card BCD (Iowa reconstruction)",
            ["BCD-CDC-IOWA", "BCD-CDC-IOWA-RECONSTRUCTED"],
            "source_qualified_punched_card_encoding",
            "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
            "The complete internally one-to-one 64-character table reconstructed by Douglas W. Jones; the source-qualified name deliberately does not claim the generic BCD-CDC identity.",
            "secondary_historical_source_exact_reconstruction",
            "medium",
        ),
        (
            "Transcode",
            [],
            "ambiguous_source_profile_family",
            "https://www.bitsavers.org/pdf/ibm/datacomm/GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf",
            "The 1970 general BSC manual defines a six-bit low-order-first Transcode table with U+003C at unit 0x0C; it cannot by itself define the generic family because the IBM 2780 profile differs.",
            "primary_historical_manual_family_split",
            "high",
        ),
        (
            "Transcode",
            [],
            "ambiguous_source_profile_family",
            "https://www.bitsavers.org/pdf/ibm/2780/GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf",
            "The 1971 IBM 2780 manual defines a six-bit low-order-first Transcode table with U+2311 at unit 0x0C; use a source-qualified child because it conflicts with the general BSC table.",
            "primary_historical_manual_family_split",
            "high",
        ),
        (
            "Transcode (IBM 2780 GA27-3005-3)",
            [
                "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3",
                "IBM-2780-SIX-BIT-TRANSCODE-1971",
                "IBM-2780-TRANSCODE-1971",
                "IBM-GA27-3005-3-TRANSCODE",
            ],
            "source_qualified_six_bit_telecom_encoding",
            "https://www.bitsavers.org/pdf/ibm/2780/GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf",
            "The complete GA27-3005-3 IBM 2780 six-bit table; unit 0x0C maps to U+2311 SQUARE LOZENGE, and the six wire bits are transmitted low-order first.",
            "primary_historical_manual_exact_profile",
            "high",
        ),
        (
            "Transcode (IBM BSC GA27-3004-2)",
            [
                "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2",
                "IBM-BSC-SIX-BIT-TRANSCODE-1970",
                "IBM-GA27-3004-2-TRANSCODE",
            ],
            "source_qualified_six_bit_telecom_encoding",
            "https://www.bitsavers.org/pdf/ibm/datacomm/GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf",
            "The complete GA27-3004-2 general Binary Synchronous Communications six-bit table; unit 0x0C maps to U+003C LESS-THAN SIGN, and the parity column is not serialized as a seventh wire bit.",
            "primary_historical_manual_exact_profile",
            "high",
        ),
        (
            "DEX MUTF-8",
            ["Android Modified UTF-8"],
            "unicode_compatibility_encoding",
            "https://source.android.com/docs/core/runtime/dex-format#mutf-8",
            "Android DEX string-data encoding.",
            "vendor_specification",
            "medium",
        ),
        (
            "UTF-9",
            ["UTF-18"],
            "joke_unicode_encoding",
            "https://www.rfc-editor.org/rfc/rfc4042.html",
            "April Fools UTF for 9-bit nonets.",
            "joke_rfc",
            "medium",
        ),
        (
            "UTF-8-MAC",
            ["utf8-mac"],
            "filesystem_normalization_variant",
            "https://developer.apple.com/library/archive/qa/qa1173/_index.html",
            "Common name for decomposed Unicode behavior in older HFS Plus contexts; not a distinct UTF.",
            "informal_name",
            "medium",
        ),
        (
            "Indian Script Code for Information Interchange",
            ["ISCII", "ISCII-91"],
            "legacy_indic_encoding",
            "https://en.wikipedia.org/wiki/Indian_Script_Code_for_Information_Interchange",
            "Indian national 8-bit/extension encoding family.",
            "historical_standard",
            "medium",
        ),
        (
            "DEC SIXBIT/ECMA-1",
            ["DEC-SIXBIT", "PDP-10-SIXBIT"],
            "six_bit_character_code",
            "https://bitsavers.org/pdf/dec/pdp10/Sze_Introduction_to_DEC_System-10_1974.pdf",
            "DECsystem-10 SIXBIT, derived from ASCII by retaining the low six bits after an octal 040 offset.",
            "vendor_manual",
            "high",
        ),
        (
            "DEC SIXBIT/ECMA-1",
            ["ECMA-1", "ECMA1"],
            "six_bit_character_code",
            "https://ecma-international.org/wp-content/uploads/ECMA-1_1st_edition_march_1963.pdf",
            "ECMA-1's normative 1963 six-bit input/output character-code table.",
            "official_standard",
            "high",
        ),
        (
            "CDC display code",
            [
                "CDC-DISPLAY-CODE",
                "CDC-DISPLAY-CODE-63",
                "CDC-DISPLAY-CODE-64",
                "CDC-DISPLAY-CODE-ASCII-63",
                "CDC-DISPLAY-CODE-ASCII-64",
                "CDC-6-12-DISPLAY-CODE-63",
                "CDC-6-12-DISPLAY-CODE-64",
                "CDC612-DISPLAY-CODE",
                "CDC-6000-DISPLAY-CODE",
                "CDC-CYBER-DISPLAY-CODE",
            ],
            "six_bit_character_code",
            "https://bitsavers.org/pdf/cdc/cyber/nos/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf",
            "CDC NOS Display Code with the complete CDC/ASCII graphic tables, documented 63/64-character colon/percent anomaly, and all 128 ASCII-to-6/12 conversions on printed pages A-1 through A-7.",
            "vendor_manual",
            "high",
        ),
        (
            "SI 960",
            [
                "SI-960",
                "SI960",
                "HEBREW-7",
                "DEC-HEBREW-7",
                "DEC-HEBREW-7BIT",
                "DEC-7-BIT-HEBREW",
            ],
            "seven_bit_character_encoding",
            "https://www.bitsavers.org/pdf/dec/_Books/_Digital_Press/Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf",
            "DEC Hebrew 7-bit replaces ASCII positions 96 through 122 with the Hebrew alphabet and is equivalent to Israeli Standards Institute Standard 960 (printed page 19 / PDF page 40).",
            "vendor_manual",
            "high",
        ),
        (
            "DEC Hebrew",
            [
                "DEC-HEBREW-8",
                "DEC-HEBREW",
                "DEC-HEBREW-8BIT",
                "DEC-HEBREW-8-BIT",
            ],
            "eight_bit_character_encoding",
            "https://www.bitsavers.org/pdf/dec/_Books/_Digital_Press/Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf",
            "DEC Hebrew 8-bit is based on DEC Multinational: positions 192 through 223 and 251 through 255 are unused, while 224 through 250 contain the Hebrew alphabet (printed page 19 / PDF page 40).",
            "vendor_manual",
            "high",
        ),
        (
            "DEC Special Graphics",
            [
                "DEC Special Graphics character set",
                "DEC-SPECIAL",
                "DEC-SPECIAL-GR",
                "DEC-SPECIAL-GRAPHIC",
                "DEC-SPECIAL-GRAPHICS",
                "DEC-SPECIAL-GRAPHIC-GR",
                "DEC-SPECIAL-GRAPHICS-GR",
                "VT100-GRAPHICS",
                "VT100-LINE-DRAWING",
            ],
            "terminal_glyph_set",
            "https://bitsavers.org/pdf/dec/terminal/vt340/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf",
            "DEC's complete 94-position Special Graphic table and its explicit GL/GR invocation rules in Figure 2-7, printed page 26 / PDF page 39.",
            "vendor_manual",
            "high",
        ),
        (
            "DEC Technical Character Set",
            [
                "DEC-TECHNICAL",
                "DEC-TECHNICAL-GR",
                "DEC-TECHNICAL-CHARACTER-SET",
                "DEC-TECHNICAL-CHARACTER-SET-GR",
                "VT300-TECHNICAL",
                "VT300-TECHNICAL-GR",
            ],
            "terminal_glyph_set",
            "https://bitsavers.org/pdf/dec/terminal/vt340/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf",
            "DEC's complete 94-position Technical table, composite-character cells, undefined cells, and explicit GL/GR invocation rules in Figure 2-8, printed page 27 / PDF page 40.",
            "vendor_manual",
            "high",
        ),
        (
            "DEC Radix-50",
            [
                "DEC-RADIX-50",
                "DEC-RADIX-50-16BE",
                "DEC-RADIX-50-16LE",
                "MOD40",
                "PDP-11-RAD50",
                "RAD50",
                "RADIX-50",
            ],
            "packed_legacy_character_code",
            "https://www.bitsavers.org/pdf/dec/pdp11/rt11/v4.0_Mar80/4_fortran/DEC-11-LFLRA_FORTRAN_Language_Reference_Manual_Jun77.pdf",
            "DEC's PDP-11 three-character base-40 word format, including the complete alphabet and packing formula on printed page A-3.",
            "vendor_manual",
            "high",
        ),
        (
            "DEC Radix-50",
            [
                "DEC-RADIX-50-18BIT",
                "DEC-RADIX-50-18BIT-24BE",
                "DEC-RADIX-50-18BIT-24LE",
                "PDP-9-RADIX-50",
                "PDP-15-RADIX-50",
            ],
            "packed_legacy_character_code",
            "https://www.bitsavers.org/pdf/dec/pdp9/DEC-9A-GUAB-D_UTILITIES.pdf",
            "DEC's PDP-9/15 three-character base-40 format with two classification bits, including the published SYMNAM vector on printed page A1-1.",
            "vendor_manual",
            "high",
        ),
        (
            "DEC Radix-50",
            [
                "DEC-RADIX-50-36BIT",
                "DEC-RADIX-50-36BIT-40BE",
                "DEC-RADIX-50-36BIT-40LE",
                "DEC-SQUOZE",
                "PDP-10-RADIX-50",
                "SQUOZE",
            ],
            "packed_legacy_character_code",
            "https://bitsavers.org/pdf/dec/pdp10/TOPS10_softwareNotebooks/vol13/AA-C780C-TB_Macro_Assembler_Reference_Manual_Apr78.pdf",
            "DEC's PDP-6/10 six-character base-40 format with four tag bits and its published SYMBOL vector on printed pages 3-56 and A-1 through A-3.",
            "vendor_manual",
            "high",
        ),
        (
            "Mac OS Devanagari encoding",
            ["MacDevanagari"],
            "legacy_macintosh_encoding",
            "https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/DEVANAGA.TXT",
            "Apple's external Mac OS Devanagari to Unicode mapping.",
            "vendor_mapping",
            "high",
        ),
        (
            "Mac OS Keyboard encoding",
            ["MacKeyboard"],
            "legacy_macintosh_encoding",
            "https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/KEYBOARD.TXT",
            "Apple's external Mac OS Keyboard to Unicode mapping.",
            "vendor_mapping",
            "high",
        ),
        (
            "Mac OS Sámi",
            ["MAC-SAMI"],
            "legacy_macintosh_encoding",
            "https://sourceware.org/git/?p=glibc.git;a=blob;f=localedata/charmaps/MAC-SAMI",
            "glibc's complete Mac Sámi charmap.",
            "upstream_charmap",
            "high",
        ),
        (
            "MacArabic encoding",
            ["MacArabic", "MAC-ARABIC"],
            "legacy_macintosh_encoding",
            "https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/ARABIC.TXT",
            "Apple's external Mac OS Arabic to Unicode mapping.",
            "vendor_mapping",
            "high",
        ),
        (
            "Tamil Script Code for Information Interchange",
            ["TSCII", "TSCII-1.7"],
            "legacy_tamil_encoding",
            "https://sourceware.org/git/?p=glibc.git;a=blob;f=localedata/charmaps/TSCII",
            "Complete glibc TSCII 1.7 charmap, including sequence mappings.",
            "upstream_charmap",
            "high",
        ),
        (
            "ZX Spectrum +3 character set",
            ["ZX-SPECTRUM-PLUS3", "AMSTRAD-CPM-PLUS"],
            "legacy_computer_encoding",
            "https://www.unicode.org/wg2/docs/n5028-19025-terminals-prop.pdf",
            "The WG2 N5028 Amstrad CP/M Plus mapping used by the ZX Spectrum +3.",
            "official_mapping_proposal",
            "high",
        ),
        (
            "MARC-8",
            ["MARC8"],
            "library_bibliographic_encoding",
            "https://www.loc.gov/marc/specifications/speccharmarc8.html",
            "Library of Congress MARC 21 legacy encoding environment.",
            "official_specification",
            "high",
        ),
        (
            "ANSEL",
            ["ISO-IR-231", "ANSI/NISO Z39.47"],
            "bibliographic_character_set",
            "https://www.loc.gov/marc/specifications/codetables/ExtendedLatin.html",
            "Extended Latin bibliographic character set used by MARC-8.",
            "official_specification",
            "high",
        ),
        (
            "ATASCII",
            ["ATARI ASCII"],
            "legacy_computer_encoding",
            "https://en.wikipedia.org/wiki/ATASCII",
            "Atari 8-bit computer character encoding.",
            "historical",
            "medium",
        ),
        (
            "Six-bit character code",
            ["SIXBIT", "six-bit code"],
            "early_computer_encoding_family",
            "https://en.wikipedia.org/wiki/Six-bit_character_code",
            "Family of pre-ASCII six-bit encodings.",
            "historical_family",
            "medium",
        ),
        (
            "Baudot code",
            [],
            "telegraph_code",
            "https://en.wikipedia.org/wiki/Baudot_code",
            "Original five-bit telegraph code; distinct revisions and derivatives exist.",
            "historical",
            "medium",
        ),
        (
            "Murray code",
            [],
            "telegraph_code",
            "https://en.wikipedia.org/wiki/Baudot_code",
            "Five-bit telegraph code derived from, but not identical to, Baudot code.",
            "historical",
            "medium",
        ),
        (
            "Chinese telegraph code",
            [],
            "telegraph_code",
            "https://en.wikipedia.org/wiki/Chinese_telegraph_code",
            "Four-digit decimal Chinese telegraph character code.",
            "historical",
            "medium",
        ),
        (
            "KOI8-F",
            [
                "KOI8-UNIFIED",
                "KOI8-F-NMSU-2008",
                "KOI8-UNIFIED-NMSU-2008",
                "CP60270-NMSU-2008",
            ],
            "legacy_cyrillic_encoding",
            "https://web.archive.org/web/20200712005106id_/http://sofia.nmsu.edu/~mleisher/Software/csets/KOI8UNI.TXT",
            "Complete 256-octet New Mexico State University Unicode mapping of Fingertip Software's KOI8 Unified, including both NO-BREAK SPACE positions and the RFC 1489-compatible U+2219 mapping at 0x95.",
            "source_qualified_unicode_mapping",
            "high",
        ),
        (
            "UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN",
            [],
            "unicode_property_token_mapping",
            "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
            "One four-decimal-digit token mapped by Unicode 17.0.0 kMainlandTelegraph; this property mapping does not define concatenated-message framing.",
            "unicode_17_0_0_property",
            "high",
        ),
        (
            "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE",
            [],
            "unicode_property_token_mapping",
            "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
            "One four-decimal-digit token mapped by Unicode 17.0.0 kTaiwanTelegraph with canonical-minimum readable reverse selection; this property mapping does not define concatenated-message framing.",
            "unicode_17_0_0_property_profile",
            "high",
        ),
        (
            "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1",
            [],
            "unicode_property_token_mapping",
            "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
            "One four-decimal-digit Unicode 17.0.0 kTaiwanTelegraph token with an explicit VPUA profile preserving duplicate-token and normalization-hazard identities; this property mapping does not define concatenated-message framing.",
            "iconvex_lossless_vpua_property_profile",
            "high",
        ),
        (
            "UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN",
            [],
            "unicode_property_token_mapping",
            "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
            "One four-decimal-digit token mapped by the provisional Unicode 17.0.0 kGB3 property; this exact snapshot has 7,236 assignments and does not claim the complete published GB 13131-1991 repertoire.",
            "unicode_17_0_0_property_profile",
            "high",
        ),
        (
            "UNIHAN-17.0.0-KGB3-ROW-CELL-GL",
            [],
            "unicode_property_row_cell_codec",
            "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
            "Source-qualified raw GL projection of the 7,236 provisional Unicode 17.0.0 kGB3 row/cell assignments; no generic GB 13131, GR/EUC, or ISO-2022 identity is claimed.",
            "iconvex_source_qualified_raw_gl_profile",
            "high",
        ),
        (
            "Braille ASCII",
            ["SimBraille"],
            "braille_encoding",
            "https://en.wikipedia.org/wiki/Braille_ASCII",
            "ASCII mapping for six-dot braille patterns.",
            "historical",
            "medium",
        ),
        (
            "Braille code",
            ["six-dot braille"],
            "tactile_character_code",
            "https://en.wikipedia.org/wiki/Braille",
            "Tactile dot-pattern code identified in character-encoding histories.",
            "historical_adjacent",
            "medium",
        ),
        (
            "International maritime signal flags",
            ["International Code of Signals flags"],
            "visual_character_code",
            "https://en.wikipedia.org/wiki/International_maritime_signal_flags",
            "Flag patterns used to encode letters and signals.",
            "historical_adjacent",
            "medium",
        ),
        (
            "Wheatstone punched-tape code",
            ["Wheatstone code"],
            "telegraph_tape_code",
            "https://en.wikipedia.org/wiki/Wheatstone_system",
            "Early punched-paper-tape representation used with telegraph systems.",
            "historical",
            "medium",
        ),
        (
            "GSM 03.38",
            ["GSM 7-bit default alphabet", "3GPP TS 23.038"],
            "telecom_character_encoding",
            "https://www.etsi.org/deliver/etsi_ts/123000_123099/123038/19.00.00_60/ts_123038v190000p.pdf",
            "GSM default alphabet and all national locking/single-shift tables.",
            "official_specification",
            "high",
        ),
        (
            "ITA2",
            ["International Telegraph Alphabet No. 2", "CCITT No. 2", "CCITT 2"],
            "telegraph_code",
            "https://www.itu.int/rec/T-REC-S.1/en",
            "Five-unit international telegraph alphabet defined by ITU-T S.1.",
            "official_specification",
            "high",
        ),
        (
            "ITA2-S2",
            ["ITU-T S.2", "case-preserving ITA2"],
            "telegraph_coding_scheme",
            "https://www.itu.int/rec/T-REC-S.2/en",
            "Two-mode ITA2 extension preserving capital and small letters.",
            "official_specification",
            "high",
        ),
        (
            "CCIR 476",
            ["CCIR-476", "SITOR", "SITOR-B", "NAVTEX"],
            "maritime_telegraph_code",
            "https://www.itu.int/rec/R-REC-M.476/en",
            "Seven-unit constant-weight direct-printing telegraph code.",
            "official_specification",
            "high",
        ),
        (
            "AIS6",
            ["AIS six-bit text", "ITU-R M.1371-6 Table 45"],
            "maritime_telecom_character_encoding",
            "https://www.itu.int/rec/R-REC-M.1371/en",
            "Six-bit AIS text table, distinct from IEC 61162 payload armoring.",
            "official_specification",
            "high",
        ),
        (
            "Telephony BCD",
            ["TBCD"],
            "telecom_digit_encoding",
            "https://www.etsi.org/deliver/etsi_ts/129000_129099/129002/",
            "Semi-octet digit representation used in 3GPP signalling.",
            "official_specification_adjacent",
            "high",
        ),
        (
            "SIM alpha identifier",
            ["USIM alpha identifier", "SIM UCS2 0x80 0x81 0x82"],
            "telecom_text_field_encoding",
            "https://www.etsi.org/deliver/etsi_ts/131100_131199/131102/",
            "GSM-default and compressed UCS2 text fields used by SIM and USIM.",
            "official_specification_adjacent",
            "high",
        ),
        (
            "Cork encoding",
            [
                "T1 encoding",
                "TeX T1 encoding",
                "TEX-T1-EC-GLYPH",
                "TEX-T1-CMAP-1.0J",
                "T1",
                "TEX-T1",
                "CORK",
                "CORK-ENCODING",
                "EC-ENCODING",
                "TEX-LATIN-1",
                "8T",
            ],
            "font_glyph_encoding",
            "https://www.tug.org/TUGboat/tb11-4/tb30ferguson.pdf",
            "The complete 256-slot Cork/TeX T1 font-glyph encoding, exposed as exact EC-glyph and CTAN CMap 1.0j semantic profiles.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "OT1 encoding",
            [
                "TEX-OT1-CMAP-1.0J",
                "TEX-OT1-0-CMAP-1.0J",
                "TEX-OT1TT-CMAP-1.0J",
                "TEX-OT1TT-0-CMAP-1.0J",
            ],
            "source_qualified_font_unicode_extraction_profiles",
            "https://tug.ctan.org/macros/latex/contrib/cmap.zip",
            "The exact CTAN cmap 1.0j TeX-OT1-0 and distinct monospaced TeX-OT1TT-0 Unicode-extraction tables. The normal CMap leaves byte 0x20 undefined; no ambiguous bare OT1 runtime alias is claimed.",
            "pinned_lppl_source_mapping_exact",
            "high",
        ),
        (
            "Formal SignWriting",
            [
                "FSW",
                "FORMAL-SIGNWRITING-IN-ASCII",
                "FORMAL-SIGNWRITING-ASCII",
                "FSW-ASCII",
                "FSW-2012",
            ],
            "signwriting_ascii_encoding",
            "https://doi.org/10.5281/zenodo.20272667",
            "Strict v1.0.0 lexical conversion between Formal SignWriting ASCII tokens and the declared SignWriting in Unicode scalar design.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "Kamenický encoding",
            [
                "KEYBCS2",
                "KAMENICKY",
                "KAMENICKY-ORIGINAL",
                "KAMENICKY-BROTHERS",
                "KEYBCS2-ORIGINAL",
                "MYSQL-KEYBCS2",
                "KEYBCS2-MYSQL",
                "MYSQL-KEYBCS2-AD-A1",
            ],
            "single_byte_character_encoding",
            "https://ftp.fi.muni.cz/pub/localization/charsets/cs-encodings-faq",
            "Complete 256-byte original text mapping from the public-domain KEYBCS2 description, plus the separately named one-byte-different MySQL profile pinned from share/charsets/keybcs2.xml; ambiguous CP895, CP867, and DOS-895 numeric identities are deliberately excluded.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "OML encoding",
            [
                "TEX-LIVE-OML-CMMI10-TOUNICODE-2026",
                "OML",
                "OML-ENCODING",
                "TEX-MATH-ITALIC",
            ],
            "tex_math_font_encoding",
            "https://raw.githubusercontent.com/latex3/latex2e/7c8574ae28a5b257f7b92cc1e5e317255644e40d/required/latex-lab/testfiles-math/mathcapture-tag-001.tpf",
            "The complete seven-bit OML cmmi10 semantic ToUnicode mapping from the pinned LaTeX release artifact.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "OMS encoding",
            [
                "TEX-LIVE-OMS-CMSY10-TOUNICODE-2026",
                "OMS",
                "OMS-ENCODING",
                "TEX-MATH-SYMBOLS",
            ],
            "tex_math_font_encoding",
            "https://raw.githubusercontent.com/latex3/latex2e/7c8574ae28a5b257f7b92cc1e5e317255644e40d/required/latex-lab/testfiles-math/mathcapture-tag-001.tpf",
            "The complete seven-bit OMS cmsy10 semantic ToUnicode mapping from the pinned LaTeX release artifact.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "PDP-1 alphanumeric codes",
            [
                "PDP-1-CONCISE-1960-INITIAL-LOWER",
                "PDP-1-CONCISE-1960-INITIAL-UPPER",
                "PDP-1-FRIDEN-FPC-8-1960-INITIAL-LOWER",
                "PDP-1-FRIDEN-FPC-8-1960-INITIAL-UPPER",
                "PDP-1-CONCISE-FIODEC-1963-INITIAL-LOWER",
                "PDP-1-CONCISE-FIODEC-1963-INITIAL-UPPER",
                "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-LOWER",
                "PDP-1-FIODEC-ODD-PARITY-8BIT-1963-INITIAL-UPPER",
            ],
            "early_computer_stateful_encoding",
            "https://bitsavers.org/pdf/dec/pdp1/F15_PDP1_Handbook_Apr60.pdf",
            "Exact 1960 Concise and odd-parity Friden FPC-8 transports plus the revised 1963 Concise and odd-parity FIO-DEC transports from F15D_PDP1_Handbook_Oct63.pdf; lower- and upper-case initial states stay explicit because neither manual defines a universal stream initial state.",
            "primary_historical_manual",
            "high",
        ),
        (
            "ABC 800",
            [
                "LUXOR-ABC800-BASIC-II-1981-CHARACTER-MODE",
                "ABC800-CHARACTER-MODE",
            ],
            "source_qualified_seven_bit_character_encoding",
            "https://www.abc80.net/archive/luxor/ABC80x/ABC800-manual-BASIC-II.pdf",
            "Exact 128-position 1981 BASIC II character-mode table; graphics mode and ambiguous bare ABC800 runtime aliases are deliberately excluded.",
            "primary_vendor_manual_exact_mapping",
            "high",
        ),
        (
            "Stanford Extended ASCII",
            [
                "RFC698-SU-AI-STANFORD-1975-FORMAT-EFFECTOR",
                "STANFORD-EXTENDED-ASCII-RFC698-FORMAT-EFFECTOR",
                "RFC698-SU-AI-STANFORD-1975-HIDDEN-GRAPHICS",
                "STANFORD-EXTENDED-ASCII-RFC698-HIDDEN-GRAPHICS",
            ],
            "source_qualified_seven_bit_graphic_profiles",
            "https://www.rfc-editor.org/rfc/rfc698.txt",
            "Both complete 128-position SU-AI graphic interpretations from RFC 698 section 6. The separate nine-bit CONTROL/META Telnet option remains a protocol adapter, and no generic runtime alias is claimed.",
            "standards_track_rfc_exact_mapping_profiles",
            "high",
        ),
        (
            "Extended Latin-8",
            ["EVERTYPE-2001-LATIN-8-EXTENDED"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/pc/LATIN8EX.TXT",
            "Complete Evertype table version 1.00 dated 2001-11-10, exposed only under an explicit publisher/year-qualified identity.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "Mac OS Armenian",
            ["EVERTYPE-2001-MAC-ARMENIAN"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/mac/ARMENIAN.TXT",
            "Complete Evertype table version 1.00 dated 2001-11-10, exposed only under an explicit publisher/year-qualified identity.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "Mac OS Barents Cyrillic",
            ["EVERTYPE-2001-MAC-BARENTS-CYRILLIC"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/mac/BARENCYR.TXT",
            "Complete Evertype table version 1.00 dated 2001-11-10 with a documented lowest-byte inverse for its duplicate U+0304 mapping.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "Mac OS Georgian",
            ["EVERTYPE-2002-MAC-GEORGIAN"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/mac/GEORGIAN.TXT",
            "Complete Evertype table version 1.01 dated 2002-02-20, exposed only under an explicit publisher/year-qualified identity.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "Mac OS Maltese/Esperanto encoding",
            ["EVERTYPE-2001-MAC-MALTESE-ESPERANTO"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/mac/MALTESE.TXT",
            "Complete Evertype table version 1.00 dated 2001-11-10, exposed only under an explicit publisher/year-qualified identity.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "Mac OS Ogham",
            ["EVERTYPE-2001-MAC-OGHAM"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/mac/OGHAM.TXT",
            "Complete Evertype table version 1.00 dated 2001-11-10 with all unassigned octets retained as invalid.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "Mac OS Turkic Cyrillic",
            ["EVERTYPE-2002-MAC-TURKIC-CYRILLIC"],
            "source_qualified_single_byte_character_encoding",
            "https://www.evertype.com/standards/mappings/mac/TURKCYR.TXT",
            "Complete Evertype table version 1.01 dated 2002-02-20, exposed only under an explicit publisher/year-qualified identity.",
            "pinned_source_mapping_exact",
            "high",
        ),
        (
            "IBM 029 card code",
            [
                "IBM-029-CARD-IOWA-824E61A9",
                "IBM-029-PUNCHED-CARD-IOWA-824E61A9",
                "IBM-029-CARD-IOWA-824E61A9-16BE",
                "IBM-029-CARD-IOWA-824E61A9-16LE",
            ],
            "source_qualified_punched_card_encoding",
            "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
            "Content-addressed Iowa reconstruction with 63 canonical scalars, the source-proved 0-8-2 decode-only blank alias, packed 12-bit MSB/LSB, and zero-padded 16-bit endian transports; generic IBM029 runtime aliases remain excluded.",
            "pinned_secondary_source_exact_reconstruction",
            "high",
        ),
        (
            "DEC 026 card code",
            [
                "DEC-026-CARD-IOWA-824E61A9",
                "DEC-026-CARD-IOWA-824E61A9-16BE",
                "DEC-026-CARD-IOWA-824E61A9-16LE",
            ],
            "source_qualified_punched_card_encoding",
            "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
            "Content-addressed Iowa reconstruction with explicit packed 12-bit MSB/LSB and zero-padded 16-bit endian transports; no generic DEC 026 identity is claimed.",
            "pinned_secondary_source_exact_reconstruction",
            "high",
        ),
        (
            "DEC 029 card code",
            [
                "DEC-029-CARD-IOWA-824E61A9",
                "DEC-029-CARD-IOWA-824E61A9-16BE",
                "DEC-029-CARD-IOWA-824E61A9-16LE",
            ],
            "source_qualified_punched_card_encoding",
            "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
            "Content-addressed Iowa reconstruction with explicit packed 12-bit MSB/LSB and zero-padded 16-bit endian transports; no generic DEC 029 identity is claimed.",
            "pinned_secondary_source_exact_reconstruction",
            "high",
        ),
        (
            "EBCD card character set",
            [
                "EBCD-CARD-IOWA-824E61A9",
                "EBCD-CARD-IOWA-824E61A9-16BE",
                "EBCD-CARD-IOWA-824E61A9-16LE",
            ],
            "source_qualified_punched_card_encoding",
            "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
            "Content-addressed Iowa reconstruction with explicit packed 12-bit MSB/LSB and zero-padded 16-bit endian transports; no generic EBCD identity is claimed.",
            "pinned_secondary_source_exact_reconstruction",
            "high",
        ),
        (
            "GE 600 punched-card code",
            [
                "GE-600-CARD-IOWA-824E61A9",
                "GE-600-CARD-IOWA-824E61A9-16BE",
                "GE-600-CARD-IOWA-824E61A9-16LE",
            ],
            "source_qualified_punched_card_encoding",
            "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
            "Content-addressed Iowa reconstruction with explicit packed 12-bit MSB/LSB and zero-padded 16-bit endian transports; no generic GE 600 identity is claimed.",
            "pinned_secondary_source_exact_reconstruction",
            "high",
        ),
        (
            "LST 1564",
            ["LIETUVYBE-52A97895-LST-1564-2000-STRICT-BLANKS"],
            "source_qualified_sequence_single_byte_encoding",
            "https://github.com/lietuvybe/standards/tree/52a97895aad2ba40e93a1da28a63c964ad63b9eb",
            "Exact commit-qualified lietuvybe snapshot with blank standard cells retained as invalid; the unavailable /P:2012 correction prevents an unqualified official-standard claim.",
            "pinned_cc_by_source_mapping_exact",
            "high",
        ),
        (
            "LST 1590-2",
            ["LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS"],
            "source_qualified_sequence_single_byte_encoding",
            "https://github.com/lietuvybe/standards/tree/52a97895aad2ba40e93a1da28a63c964ad63b9eb",
            "Exact commit-qualified lietuvybe snapshot with blank standard cells retained as invalid; the unavailable /P:2012 correction prevents an unqualified official-standard claim.",
            "pinned_cc_by_source_mapping_exact",
            "high",
        ),
        (
            "LST 1590-4",
            ["LIETUVYBE-52A97895-LST-1590-4-2000-STRICT-BLANKS"],
            "source_qualified_sequence_single_byte_encoding",
            "https://github.com/lietuvybe/standards/tree/52a97895aad2ba40e93a1da28a63c964ad63b9eb",
            "Exact commit-qualified lietuvybe snapshot with blank standard cells retained as invalid; the unavailable /P:2012 correction prevents an unqualified official-standard claim.",
            "pinned_cc_by_source_mapping_exact",
            "high",
        ),
        (
            "VNI Character Set",
            [
                "VIETUNICODE-2002-VNI-ASCII-DOS",
                "VIETUNICODE-2002-VNI-ANSI-WIN-UNIX",
                "VIETUNICODE-2002-VNI-MAC",
                "VIETUNICODE-2002-VNI-INTERNET-MAIL",
            ],
            "source_qualified_variable_length_vietnamese_profiles",
            "https://vietunicode.sourceforge.net/charset/vni.html",
            "Four exact 2002 VietUnicode profiles, independently matched to Encode::VN 0.06. Identities remain profile-qualified because byte-token and inverse semantics differ, including documented Internet Mail boundary collisions.",
            "pinned_source_mapping_exact_with_independent_oracle",
            "high",
        ),
        (
            "LY1 encoding",
            [
                "CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA",
                "CTAN-TEXNANSI-1.1-AGL-4036A9CA",
            ],
            "source_qualified_glyph_vector_unicode_encoding",
            "https://mirrors.ctan.org/fonts/psfonts/ly1.zip",
            "Exact TeX'n'ANSI 1.1 vector composed with Adobe Glyph List commit 4036a9ca; five .notdef positions and the internal-only cwm glyph remain invalid, and no generic LY1 or TEXNANSI alias is claimed.",
            "pinned_lppl_vector_and_bsd_glyph_mapping_exact",
            "high",
        ),
        (
            "PostScript Latin 1 Encoding",
            [
                "ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA",
                "ADOBE-POSTSCRIPT-3-ISOLATIN1ENCODING-AGL-4036A9CA",
            ],
            "source_qualified_glyph_vector_unicode_encoding",
            "https://www.adobe.com/jp/print/postscript/pdfs/PLRM.pdf",
            "Exact PostScript LanguageLevel 3 Table E.7 vector composed with Adobe Glyph List commit 4036a9ca; all 205 glyph positions are mapped and the 51 undefined positions stay invalid without a generic PostScript Latin 1 alias.",
            "primary_vector_and_pinned_bsd_glyph_mapping_exact",
            "high",
        ),
        (
            "Tamil All Character Encoding",
            [
                "TAMILVU-TACE16-APPENDIX-D-2010-16BE",
                "TACE16-APPENDIX-D-2010-BE",
                "TAMILVU-TACE16-APPENDIX-D-2010-16LE",
                "TACE16-APPENDIX-D-2010-LE",
            ],
            "source_qualified_sixteen_bit_sequence_encoding",
            "https://www.tamilvu.org/coresite/download/final_report.pdf",
            "Exact 380-unit Appendix D mapping from the 2010 Tamil Virtual University report. The 360 declared Unicode equivalents and 20 source PUA identities are exposed through explicit zero-BOM 16BE and 16LE transports because the report defines no byte order; TACE16 is retained only as a catalog concept alias, not a bare runtime codec identity.",
            "primary_government_report_exact_mapping_explicit_endian_transports",
            "high",
        ),
        (
            "Wang International Standard Code for Information Interchange",
            ["WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854"],
            "source_qualified_single_byte_character_encoding",
            "https://bitsavers.org/pdf/wang/vs/800-1149-01_VS_Multi-Station_Users_Ref_198312.pdf",
            "Exact Wang 1983 Appendix D byte-to-glyph chart with its Unicode interpretation pinned to Wikipedia revision 1352856854. The source-qualified identity has 221 assigned positions and makes no generic WISCII alias claim.",
            "primary_vendor_chart_with_revision_pinned_unicode_interpretation",
            "high",
        ),
        (
            "Windows Polytonic Greek",
            ["WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK"],
            "source_qualified_single_byte_character_encoding",
            "https://en.wikipedia.org/w/index.php?oldid=1354794598",
            "Complete 256-position Paratype Windows Polytonic Greek table pinned to revision 1354794598, whose B5/FF ordering is kept distinct from the documented older FontLab profile.",
            "revision_pinned_cc_by_sa_secondary_mapping_exact",
            "high",
        ),
        (
            "Windows-1270",
            ["WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270"],
            "source_qualified_single_byte_character_encoding",
            "https://en.wikipedia.org/w/index.php?oldid=1340817319",
            "Exact 249-position Sami Windows CP1270 mapping pinned to Wikipedia revision 1340817319 and independently matched against EKI's SAMI_WIN table; seven octets stay undefined and no generic CP1270 alias is claimed.",
            "revision_pinned_secondary_mapping_with_independent_eki_parity",
            "high",
        ),
        (
            "ABICOMP character set",
            [
                "ABICOMP",
                "BRAZIL-ABICOMP",
                "CP3848",
                "CODE-PAGE-3848",
                "FREEDOS-CP3848",
            ],
            "single_byte_character_encoding",
            "https://archive.org/download/manuallib-id-2525457/2525457.pdf",
            "Exact 192-defined-byte Brazil-ABICOMP / code-page-3848 profile from the Star LC-8021 manual, independently confirmed by Epson 749516.pdf and FreeDOS CPIDOS; PCL-13P, PCL-14P, and ABICOMP-INTERNATIONAL remain excluded because no exact byte-identical mapping was established.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "BraSCII",
            [
                "BRASCII",
                "BRA-SCII",
                "ABNT",
                "ABNT-BRASCII",
                "NBR-9611",
                "NBR-9611:1991",
                "NBR-9614",
                "NBR-9614:1986",
                "CP3847",
                "CODE-PAGE-3847",
                "BRAZIL-ABNT",
                "BRAZIL-ABNT-3847",
            ],
            "single_byte_character_encoding",
            "https://files.support.epson.com/pdf/sc200_/sc200_u1.pdf",
            "Complete NBR-9611 BraSCII / code-page-3847 octet mapping from Epson sc200_u1.pdf, independently confirmed by Star 2525457.pdf; C0 and C1 use the explicitly documented Unicode-identity text transport policy.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "JIS7-KANJI",
            ["ISO2022JP-KANJI", "KERMIT-JIS7-KANJI"],
            "stateful_multibyte_encoding",
            "https://raw.githubusercontent.com/davidrg/ckwin/8e977425d2f7f618d14aa466d516e9b79787ffc6/ckuxla.c",
            "Exact Kermit JIS7-KANJI state machine from pinned ckuxla.c and its complete 6,879-position JIS X 0208 mapping cross-checked against Unicode JIS0208.TXT; deliberately distinct from ICU JIS7 and generic ISO-2022-JP.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "MacEsperanto encoding",
            ["MACOS_ESPERANTO", "MACESPERANTO", "MAC-ESPERANTO", "MACOS-ESPERANTO"],
            "single_byte_character_encoding",
            "https://www.evertype.com/standards/eo/eo-table.html",
            "Complete MacOS Esperanto Table version: 0.3 mapping from Michael Everson's eo-table.html; all 256 octets are unique after the explicit Unicode-identity C0/DEL text transport policy.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "VSCII",
            [
                "VSCII-2",
                "TCVN-5712-2",
                "TCVN5712-2",
                "TCVN5712-2:1993",
                "TCVN-VN2",
                "VN2",
                "ISO-IR-180",
            ],
            "single_byte_character_encoding",
            "https://itscj.ipsj.or.jp/ir/180.pdf",
            "Exact TCVN 5712:1993 VN2 right-hand graphic set from ISO-IR-180, independently matched against TCVN5712-2.TXT; distinct RFC 1456 VISCII and VN1/TCVN aliases are deliberately excluded.",
            "primary_source_exact_mapping",
            "high",
        ),
        (
            "Lotus International Character Set",
            ["LICS", "LOTUS-INTERNATIONAL-CHARACTER-SET"],
            "single_byte_character_encoding",
            "https://www.retroisle.com/others/hp95lx/OriginalDocs/95LX_UsersGuide_F1000-90001_826pages_Jun91.pdf",
            "Complete June 1991 HP 95LX User's Guide Appendix F LICS profile; the Xerox May 1988 https://bitsavers.org/pdf/xerox/viewpoint/VP_2.0/610E12320_File_Conversion_Reference_Volume_10_May88.pdf independently agrees on every shared assignment but omits four later HP assignments, so the earlier incomplete profile is not equivalent and is not merged.",
            "primary_vendor_manual_exact_mapping",
            "high",
        ),
        (
            "Perso-Arabic Script Code for Information Interchange",
            [
                "PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT",
                "PASCII-CDAC-GIST-1.0-2002-SINDHI-UNICODE17-BEST-FIT",
                "PASCII-CDAC-GIST-1.0-2002-LOSSLESS-VPUA-1",
                "PASCII-CDAC-GIST-1.0-2002-RAW-VPUA-1",
            ],
            "source_qualified_legacy_octet_encoding_profiles",
            "https://www.cs.cmu.edu/afs/cs.cmu.edu/project/cmt-40/Nice/Urdu-MT/code/Tools/Encoding_Conversion/EncodingInfo/PASCIIStandard.pdf",
            "The complete C-DAC GIST PASCII Version 1.0 byte chart from October 2002. Iconvex exposes a language-neutral exact VPUA source-identity profile, a forensic raw profile, and separately named non-normative Unicode 17 Urdu/Kashmiri and Sindhi best-fit projections; no unqualified PASCII runtime alias is claimed.",
            "primary_government_byte_chart_with_explicit_projection_policy",
            "high",
        ),
        (
            "tap code",
            [
                "US-ARMY-GTA-31-70-001-TAP-CODE-PAIR-VALUES",
                "US-ARMY-POW-TAP-CODE-PAIR-VALUES",
                "GTA-31-70-001-TAP-CODE-PAIR-VALUES",
                "POW-TAP-CODE-5X5-PAIR-VALUES",
            ],
            "human_signaling_pair_value_encoding",
            "https://rdl.train.army.mil/catalog-ws/view/100.ATSC/B18B36F6-2596-43BA-B50A-EFC562032BA9-1300757028781/gta31_70_001.pdf",
            "Exact January 2015 U.S. Army GTA 31-70-001 fixed 25-letter word matrix serialized as Iconvex numeric pair values, independently cross-checked against Naval History's https://www.history.navy.mil/content/dam/nhhc/research/publications/Publication-PDF/BattleBehindBars.pdf; the project transport is not physical U.S. Army wire bytes, spaces, numbers, and alternate matrices remain excluded, and the runtime does not claim generic TAP-CODE identity.",
            "primary_government_publication_exact_profile",
            "high",
        ),
        (
            "UNIVAC-I-EXPANDED-1959",
            [
                "UNIVAC I character code",
                "UNIVAC I six-bit code",
                "UNIVAC-I-63",
                "UNIVAC-I-XS3-63",
                "UNIVAC-I-EXPANDED-1959-LOSSLESS-VPUA",
                "UNIVAC-I-EXPANDED-1959-RAW-VPUA",
                "UNIVAC-I-EXPANDED-1959-ODD-PARITY-7BIT",
                "UNIVAC-I-EXPANDED-1959-PAPER-TAPE-ROW",
            ],
            "early_computer_encoding",
            "https://bitsavers.org/pdf/univac/univac1/UNIVAC1_Programming_1959.pdf",
            "Complete expanded 63-character UNIVAC I code, odd-parity checked representation, and physical paper-tape row layout.",
            "primary_historical_manual",
            "high",
        ),
        (
            "ECMA-44 punched-card representation",
            [
                "ECMA-44",
                "ECMA-44-7BIT-CARD-RAW",
                "ECMA-44-8BIT-CARD-RAW",
            ],
            "punched_card_encoding",
            "https://ecma-international.org/publications-and-standards/standards/ecma-44/",
            "Raw code-combination punched-card representation of ECMA 7-bit and 8-bit coded character sets; Unicode meaning requires a separately selected repertoire.",
            "withdrawn_standard",
            "medium",
        ),
    ]
    for arrangement in "ABCDEFGHJK":
        aliases = [f"IBM-24-26-ARRANGEMENT-{arrangement}"]
        if arrangement == "A":
            aliases.extend(
                [
                    "IBM 026 Commercial card code",
                    "IBM-026-COMMERCIAL-CARD-CODE",
                    "BCD-A",
                ]
            )
        elif arrangement == "H":
            aliases.extend(
                [
                    "IBM 026 FORTRAN card code",
                    "IBM-026-FORTRAN-CARD-CODE",
                    "BCD-H",
                ]
            )

        rows.append(
            (
                f"IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-{arrangement}",
                aliases,
                "punched_card_encoding",
                "https://bitsavers.org/pdf/ibm/punchedCard/Keypunch/024-026/A24-0520-3_24_26_Card_Punch_Reference_Manual_Oct1965.pdf",
                f"The exact logical twelve-row punched-card profile for IBM 24/26 Figure 23 special-character arrangement {arrangement}; byte transports are separately named zero-padded 16BE/16LE project serializations.",
                "primary_historical_manual_exact_mapping",
                "high",
            )
        )

    rows.append(
        (
            "LMBCS-1",
            ["Lotus Multi-Byte Character Set optimization group 1"],
            "stateful_character_encoding",
            "https://github.com/unicode-org/icu/blob/release-78-3/icu4c/source/common/ucnv_lmb.cpp",
            "ICU's advertised LMBCS optimization-group 1 converter.",
            "executable_icu_converter",
            "high",
        )
    )
    rows.extend(
        (
            f"LMBCS-{group}",
            [f"Lotus Multi-Byte Character Set optimization group {group}"],
            "stateful_character_encoding",
            "https://github.com/unicode-org/icu/blob/release-78-3/icu4c/source/common/ucnv_lmb.cpp",
            f"ICU's executable but unadvertised LMBCS optimization-group {group} converter.",
            "unadvertised_executable_icu_converter",
            "high",
        )
        for group in (2, 3, 4, 5, 6, 8, 11, 16, 17, 18, 19)
    )
    rows.extend(
        [
            (
                "UNIVAC 1100 Series FIELDATA",
                [
                    "FIELDATA-UNIVAC-1100",
                    "UNIVAC-1100-FIELDATA",
                    "FIELDATA-1100",
                    "UNISYS-FIELDATA",
                    "EXEC-8-FIELDATA",
                    "UNIVAC-1106-FIELDATA",
                    "UNIVAC-1108-FIELDATA",
                ],
                "early_computer_encoding",
                "https://bitsavers.org/pdf/univac/1100/exec/UP-7824r1_EXEC_8_Hw_Sw_Summary_1974.pdf",
                "The complete standard 64-unit FIELDATA table for the UNIVAC 1100 Series.",
                "primary_historical_manual",
                "high",
            ),
            (
                "UNIVAC 4009 FIELDATA",
                [
                    "FIELDATA-UNIVAC-4009-INPUT",
                    "FIELDATA-UNIVAC-4009-OUTPUT",
                    "FIELDATA-UNIVAC-4009-LOSSLESS-VPUA",
                    "FIELDATA-UNIVAC-4009-RAW-VPUA",
                    "UNIVAC-4009-FIELDATA-INPUT",
                    "UNIVAC-4009-FIELDATA-OUTPUT",
                    "UNIVAC-4009-FIELDATA-LOSSLESS-VPUA",
                    "UNIVAC-4009-FIELDATA-RAW-VPUA",
                ],
                "early_computer_encoding",
                "https://www.fourmilab.ch/documents/univac/manuals/pdf/1108/UP-7604r1_1106_1108_Systems_4009_Display_Console_Programmer_Reference_1974.pdf",
                "The complete directional octal code/action table for the UNIVAC 1106/1108 Systems 4009 Display Console.",
                "primary_historical_manual",
                "high",
            ),
            (
                "TI-83 Plus character set",
                [
                    "TI-83-PLUS-LARGE",
                    "TI-83-PLUS-LARGE-LOSSLESS-VPUA",
                    "TI-83-PLUS-LARGE-RAW-VPUA",
                    "TI-83-PLUS-SMALL",
                    "TI-83-PLUS-SMALL-LOSSLESS-VPUA",
                    "TI-83-PLUS-SMALL-RAW-VPUA",
                ],
                "calculator_character_encoding",
                "https://education.ti.com/download/en/ed-tech/830D08FF31804AEAA2F03B8F5E89AD14/672891A1E98349CAB91C11B4928C253C/sdk83pguide.pdf",
                "The complete TI-83 Plus Developer Guide large- and small-font byte tables, each with readable, mixed-lossless VPUA, and raw VPUA profiles.",
                "primary_vendor_manual",
                "high",
            ),
            (
                "TI-89 / TI-92 Plus character set",
                [
                    "TI-89-92-PLUS-AMS-2.0",
                    "TI-89-92-PLUS-AMS-2.0-VISIBLE",
                    "TI-89-92-PLUS-AMS-2.0-LOSSLESS-VPUA",
                    "TI-89-92-PLUS-AMS-2.0-RAW-VPUA",
                ],
                "calculator_character_encoding",
                "https://education.ti.com/download/en/ed-tech/2110B5BC591D44E1AF4C28F00A6614B6/0470DB419F2144349E4032AFE3C0DD7E/8992bookeng.pdf",
                "The complete TI-89/TI-92 Plus AMS 2.0 byte table, with source-glyph, visible-control, mixed-lossless VPUA, and raw VPUA profiles.",
                "primary_vendor_manual",
                "high",
            ),
        ]
    )

    return [
        Record(name, aliases, "supplement", url, name, kind, description, status, confidence)
        for name, aliases, kind, url, description, status, confidence in rows
    ]


def merge_records(records: list[Record]) -> list[dict[str, object]]:
    union = UnionFind(len(records))
    iconvex_supported_keys = set(ICONVEX_EXTERNAL_CODEC_KEYS)
    iconvex_supported_keys.update(
        key(label)
        for record in records
        if record.source == "gnu_libiconv" and record.kind == "gnu_fixed_codec"
        for label in record.labels()
    )
    anchors: dict[int, set[str]] = {
        index: ({record.source_id} if record.source == "gnu_libiconv" else set())
        for index, record in enumerate(records)
    }

    def merge_key(label: str) -> str | None:
        normalized = key(label)
        # Formal source titles retain "ISO/IEC" while charset registries
        # conventionally omit "IEC". Numbered 8859 parts are exact codec
        # identities; the unnumbered family is deliberately untouched.
        if match := re.fullmatch(r"isoiec8859(\d+)", normalized):
            normalized = "iso8859" + match.group(1)
        if (
            len(normalized) < 2
            or normalized in AMBIGUOUS_KEYS
            or re.fullmatch(r"cp0*\d+", normalized)
        ):
            return None
        return normalized

    def guarded_union(left: int, right: int) -> bool:
        left_root = union.find(left)
        right_root = union.find(right)
        if left_root == right_root:
            return True
        if anchors[left_root] and anchors[right_root] and anchors[left_root] != anchors[right_root]:
            return False
        combined = anchors[left_root] | anchors[right_root]
        union.union(left_root, right_root)
        root = union.find(left_root)
        anchors[root] = combined
        return True

    # GNU libiconv codecs are semantic anchors. Alias graphs are not globally
    # transitive: vendors reuse labels such as CP1200, Unicode, and UTF-16 for
    # mappings with different byte order or revision. Attach an outside record
    # only when all its direct GNU-label matches point to exactly one codec.
    gnu_key_owners: defaultdict[str, set[int]] = defaultdict(set)
    for index, record in enumerate(records):
        if record.source != "gnu_libiconv":
            continue
        for label in record.labels():
            normalized = merge_key(label)
            if normalized:
                gnu_key_owners[normalized].add(index)
    unique_gnu_owner = {
        normalized: next(iter(indices))
        for normalized, indices in gnu_key_owners.items()
        if len(indices) == 1
    }
    gnu_codec_owner = {
        record.source_id: index
        for index, record in enumerate(records)
        if record.source == "gnu_libiconv"
    }

    for index, record in enumerate(records):
        if record.source == "gnu_libiconv":
            continue
        matching_anchors = {
            unique_gnu_owner[normalized]
            for label in record.labels()
            if (normalized := merge_key(label)) in unique_gnu_owner
        }
        audited_codec = AUDITED_GNU_SOURCE_ID_MERGES.get(
            f"{record.source}:{record.source_id}"
        )
        if audited_codec:
            matching_anchors.add(gnu_codec_owner[audited_codec])
        if len(matching_anchors) == 1:
            guarded_union(index, next(iter(matching_anchors)))

    # Merge remaining records only by canonical name. Aliases stay visible in
    # output, but cannot act as multi-hop bridges between unrelated codecs.
    canonical_owner: dict[str, int] = {}
    ambiguous_canonical: set[str] = set()
    for index, record in enumerate(records):
        normalized = merge_key(record.name)
        normalized = AUDITED_CANONICAL_MERGES.get(normalized, normalized)
        if not normalized or normalized in ambiguous_canonical:
            continue
        if normalized not in canonical_owner:
            canonical_owner[normalized] = index
            continue
        if not guarded_union(index, canonical_owner[normalized]):
            ambiguous_canonical.add(normalized)
            canonical_owner.pop(normalized, None)

    groups: defaultdict[int, list[Record]] = defaultdict(list)
    for index, record in enumerate(records):
        groups[union.find(index)].append(record)
    assert all(
        len({record.source_id for record in group if record.source == "gnu_libiconv"}) <= 1
        for group in groups.values()
    ), "alias merge collapsed distinct GNU libiconv codecs"

    merged: list[dict[str, object]] = []
    confidence_rank = {"high": 0, "medium": 1, "candidate": 2}
    for group in groups.values():
        preferred = min(
            group,
            key=lambda record: (
                SOURCE_PRIORITY.get(record.source, 99),
                len(record.name),
                record.name.casefold(),
            ),
        )
        all_labels = unique(label for record in group for label in record.labels())
        aliases = [label for label in all_labels if label.casefold() != preferred.name.casefold()]
        sources = sorted({record.source for record in group}, key=lambda value: SOURCE_PRIORITY.get(value, 99))
        gnu = [record for record in group if record.source == "gnu_libiconv"]
        gnu_fixed = [record for record in gnu if record.kind == "gnu_fixed_codec"]
        iconvex_external = any(
            support_key_variants(label) & iconvex_supported_keys
            for record in group
            for label in record.labels()
        ) or any(
            record.source == "rfc1345"
            and key(record.name) not in ICONVEX_RFC1345_QUARANTINED_KEYS
            for record in group
        )
        if key(preferred.name) in OPENJDK_QUARANTINED_KEYS:
            iconvex_external = False
        confidence = min(group, key=lambda record: confidence_rank[record.confidence]).confidence
        if sources == ["wikipedia"]:
            confidence = "candidate"
        item = {
                "name": preferred.name,
                "aliases": sorted(aliases, key=str.casefold),
                "kinds": sorted({record.kind for record in group}),
                "sources": sources,
                "source_ids": unique(
                    f"{record.source}:{record.source_id}" for record in group if record.source_id
                ),
                "source_urls": unique(record.source_url for record in group),
                "descriptions": unique(record.description for record in group if record.description),
                "statuses": sorted({record.status for record in group if record.status}),
                "confidence": confidence,
                "gnu_libiconv_1_19": "yes" if gnu else "no",
                "gnu_canonical": gnu[0].name if gnu else "",
                "iconvex": "yes" if gnu_fixed or iconvex_external else "no",
                "record_count": len(group),
            }
        item["implementation_disposition"] = implementation_disposition(item)
        merged.append(item)

    merged.sort(key=lambda item: (str(item["name"]).casefold(), str(item["name"])))
    for index, item in enumerate(merged, 1):
        item["catalog_id"] = f"ENC-{index:04d}"
    return merged


def implementation_disposition(item: dict[str, object]) -> str:
    """Classify an unsupported catalog row by its exact implementation target."""
    name = key(str(item["name"]))
    kinds = set(str(value) for value in item["kinds"])

    if "unicode_property_token_mapping" in kinds:
        if name in IMPLEMENTED_PROPERTY_TOKEN_MAPPING_KEYS:
            return "implemented_property_token_mapping"
        return "property_token_mapping_gap"
    if disposition := AUDITED_NON_CODEC_DISPOSITIONS.get(name):
        return disposition
    if item["iconvex"] == "yes":
        return "implemented"

    if "locale_abi_adapter" in kinds:
        return "platform_adapter"
    if "unicode_character_registry_component" in kinds:
        return "registry_component"
    if "sgml_entity_mapping" in kinds:
        return "entity_mapping"
    if "iso_ir_coding_system" in kinds:
        return "non_text_coding_system"
    if "openjdk_internal_component" in kinds:
        return "internal_component"
    if name == "unknown8bit":
        return "placeholder"
    if name == "ibm61952":
        return "retired_invalid"
    if name in {"ibm65534", "ibm65535"}:
        return "control_value"
    if name in {
        "isounicodeibm1261",
        "isounicodeibm1264",
        "isounicodeibm1265",
        "isounicodeibm1268",
        "isounicodeibm1276",
    }:
        return "repertoire_profile"
    if name in {
        "armscii",
        "compatibilityencodingschemeforutf16",
        "ebcdic",
        "ecma6",
        "gost10859",
        "iso646",
        "isoiec10646unicode",
        "isoiec8859",
        "jusib1003",
        "teletext",
        "teletextcharacterset",
        "utf9andutf18",
    }:
        return "encoding_family"
    if name == "ecma48":
        return "control_standard"
    if name == "isoiec885912":
        return "withdrawn_unassigned_part"
    if name == "portablecharacterset":
        return "repertoire_abstraction"
    if name in {"hkscs", "koi8b"}:
        return "repertoire_profile"
    if name == "hkscsids":
        return "mapping_notation"
    if item["confidence"] == "candidate":
        return "research_candidate"
    return "codec_gap"


def pipe(values: Iterable[object]) -> str:
    return " | ".join(str(value).replace("|", "\\|") for value in values)


def write_catalog(catalog: list[dict[str, object]], source_counts: Counter[str], fetcher: Fetcher) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = OUT_DIR / "known_encodings.csv"
    columns = [
        "catalog_id",
        "name",
        "aliases",
        "kinds",
        "confidence",
        "gnu_libiconv_1_19",
        "gnu_canonical",
        "iconvex",
        "sources",
        "source_ids",
        "source_urls",
        "statuses",
        "descriptions",
        "record_count",
        "implementation_disposition",
    ]
    def write_csv(path: Path, rows: Iterable[dict[str, object]]) -> None:
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=columns)
            writer.writeheader()
            for item in rows:
                writer.writerow(
                    {
                        column: pipe(item[column]) if isinstance(item[column], list) else item[column]
                        for column in columns
                    }
                )

    write_csv(csv_path, catalog)
    unsupported = [item for item in catalog if item["gnu_libiconv_1_19"] == "no"]
    write_csv(OUT_DIR / "gnu_libiconv_1_19_unsupported.csv", unsupported)

    generated = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    confidence_counts = Counter(str(item["confidence"]) for item in catalog)
    gnu_supported = sum(item["gnu_libiconv_1_19"] == "yes" for item in catalog)
    iconvex_supported = sum(item["iconvex"] == "yes" for item in catalog)
    disposition_counts = Counter(str(item["implementation_disposition"]) for item in catalog)
    disposition_counts["property_token_mapping_gap"] += 0
    high_confidence_unsupported = sum(item["confidence"] == "high" for item in unsupported)
    other_audited_non_codec = (
        len(catalog)
        - disposition_counts["implemented"]
        - disposition_counts["implemented_property_token_mapping"]
        - disposition_counts["codec_gap"]
        - disposition_counts["property_token_mapping_gap"]
        - disposition_counts["research_candidate"]
    )

    source_descriptions = {
        "iana": "IANA Character Sets registry",
        "whatwg": "WHATWG Encoding Standard",
        "gnu_libiconv": "GNU libiconv 1.19 fixed definitions and locale adapters",
        "glibc": "GNU C Library gconv module registry",
        "icu": "ICU converter aliases",
        "openjdk": "OpenJDK charset mapping registry",
        "microsoft": "Microsoft code-page identifiers",
        "ibm_i": "IBM i defined CCSIDs",
        "iso_ir": "ISO International Register of coded character sets",
        "rfc1345": "RFC 1345 charset tables",
        "unicode_mappings": "Unicode vendor and obsolete mapping archives",
        "python": "Python standard codecs",
        "kermit": "Kermit 95 legacy/terminal character sets",
        "wikidata": "Wikidata instances of character-encoding subclasses",
        "wikipedia_historical": "Wikipedia historical information-system charset inventory",
        "punched_cards": "University of Iowa historical punched-card code inventory",
        "wikipedia": "English Wikipedia Character sets category tree",
        "supplement": "Named gaps from vendor specifications and RFCs",
    }

    lines = [
        "# Known text encodings: public-source catalog",
        "",
        f"Generated: `{generated}`.",
        "",
        "Best-effort exhaustive catalog of publicly documented text encodings, coded character",
        "sets, code pages, Unicode transfer formats, historical terminal/telegraph sets, and",
        "closely adjacent glyph or data syntaxes. Exact aliases remain preserved in CSV.",
        "",
        "## Scope limits",
        "",
        "Literal completeness is impossible: private and undocumented encodings exist; vendor",
        "registries evolve; identical names can denote different mappings; different names can",
        "denote the same mapping; and historical sources often specify a repertoire or component",
        "set rather than a standalone byte-stream codec. `candidate` rows come from broad",
        "encyclopedic category membership and require mapping-level validation before implementation.",
        "",
        "Binary-to-text formats, compression, encryption, markup entities, natural-language writing",
        "systems, and font files are excluded unless a cited source classifies their character-to-code",
        "mapping as an encoding or coded character set.",
        "",
        "## Summary",
        "",
        f"- Merged catalog entries: **{len(catalog)}**.",
        f"- High confidence: **{confidence_counts['high']}**; medium: **{confidence_counts['medium']}**; candidate: **{confidence_counts['candidate']}**.",
        f"- GNU libiconv 1.19-supported clusters: **{gnu_supported}**; unsupported clusters: **{len(catalog) - gnu_supported}**.",
        f"- High-confidence GNU libiconv-unsupported clusters: **{high_confidence_unsupported}**.",
        f"- Iconvex-supported codec clusters: **{iconvex_supported}**; unsupported codec/non-codec clusters: **{len(catalog) - iconvex_supported}**.",
        f"- Implemented property-token mappings: **{disposition_counts['implemented_property_token_mapping']}**; property-token mapping gaps: **{disposition_counts['property_token_mapping_gap']}**.",
        f"- Actionable codec gaps: **{disposition_counts['codec_gap']}**; research candidates: **{disposition_counts['research_candidate']}**; other audited non-codec/deferred records: **{other_audited_non_codec}**.",
        "- GNU/Iconvex support uses conservative direct alias matching against GNU codec anchors.",
        "  Iconvex-only external package codecs are matched by explicit audited keys.",
        "  Ambiguous aliases and transitive alias bridges stay separate.",
        "  Audited non-codecs are explained in `NON_CODEC_DISPOSITIONS.md`;",
        "  `codec_gap` rows are codec targets and `property_token_mapping_gap` rows",
        "  are property-token mapping targets.",
        "",
        "## Focused comparisons",
        "",
        "- [Direct Wikipedia character-set clusters absent from GNU libiconv 1.19](WIKIPEDIA_MISSING_FROM_GNU.md)",
        "  ([machine-readable CSV](WIKIPEDIA_MISSING_FROM_GNU.csv)).",
        "",
        "## Sources",
        "",
        "| Source | Raw records | Description |",
        "|---|---:|---|",
    ]
    for source in sorted(source_counts, key=lambda value: SOURCE_PRIORITY.get(value, 99)):
        lines.append(
            f"| `{source}` | {source_counts[source]} | {source_descriptions.get(source, '')} |"
        )
    lines.extend(
        [
            "",
            "## Complete merged catalog",
            "",
            "| ID | Name | Kind(s) | Confidence | GNU 1.19 | Iconvex | Disposition | Sources |",
            "|---|---|---|:---:|:---:|:---:|---|---|",
        ]
    )
    for item in catalog:
        name = str(item["name"]).replace("|", "\\|")
        kinds = ", ".join(str(value) for value in item["kinds"]).replace("|", "\\|")
        sources = ", ".join(str(value) for value in item["sources"])
        lines.append(
            f"| {item['catalog_id']} | `{name}` | {kinds} | {item['confidence']} | "
            f"{item['gnu_libiconv_1_19']} | {item['iconvex']} | "
            f"{item['implementation_disposition']} | {sources} |"
        )
    (OUT_DIR / "KNOWN_ENCODINGS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    manifest = {
        "generated_at": generated,
        "catalog_entries": len(catalog),
        "gnu_libiconv_1_19_unsupported_entries": len(unsupported),
        "gnu_libiconv_1_19_high_confidence_unsupported_entries": high_confidence_unsupported,
        "implementation_disposition_counts": dict(disposition_counts),
        "source_record_counts": dict(source_counts),
        "retrievals": fetcher.manifest,
    }
    (OUT_DIR / "encoding_catalog_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    # Keep the direct-Wikipedia-versus-GNU projection coupled to the catalog
    # build while retaining a cheap standalone --check mode for CI/tests.
    subprocess.run(
        [sys.executable, str(ROOT / "tools/generate_wikipedia_gap_report.py")],
        check=True,
    )


def main() -> None:
    fetcher = Fetcher()
    parsers = [
        ("iana", lambda: parse_iana(fetcher)),
        ("whatwg", lambda: parse_whatwg(fetcher)),
        ("gnu_libiconv", parse_gnu_local),
        ("glibc", lambda: parse_glibc(fetcher)),
        ("icu", lambda: parse_icu(fetcher)),
        ("openjdk", lambda: parse_openjdk(fetcher)),
        ("microsoft", lambda: parse_microsoft(fetcher)),
        ("ibm_i", lambda: parse_ibm(fetcher)),
        ("iso_ir", lambda: parse_iso_ir(fetcher)),
        ("rfc1345", lambda: parse_rfc1345(fetcher)),
        ("unicode_mappings", lambda: parse_unicode_mappings(fetcher)),
        ("python", lambda: parse_python(fetcher)),
        ("kermit", lambda: parse_kermit(fetcher)),
        ("wikidata", lambda: parse_wikidata(fetcher)),
        ("wikipedia_historical", lambda: parse_wikipedia_historical(fetcher)),
        ("punched_cards", lambda: parse_punched_card_codes(fetcher)),
        ("wikipedia", lambda: parse_wikipedia(fetcher)),
        ("supplement", supplemental_records),
    ]
    records: list[Record] = []
    counts: Counter[str] = Counter()
    for source, parser in parsers:
        parsed = parser()
        counts[source] = len(parsed)
        records.extend(parsed)
        print(f"{source}: {len(parsed)} records", file=sys.stderr)
    catalog = merge_records(records)
    write_catalog(catalog, counts, fetcher)
    print(f"merged: {len(catalog)} entries", file=sys.stderr)


if __name__ == "__main__":
    main()
