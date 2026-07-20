# Telecom research-source provenance

This manifest covers every file retained below `tmp/`. Those files are
**repository-only research evidence**, are **excluded from Hex**, and are not
runtime or test dependencies. The package selector in `mix.exs` deliberately
does not include `tmp`. No upstream artifact is relicensed as LGPL; Iconvex's
LGPL license applies only to original Iconvex implementation material.

Absence of a license statement below means exactly that: no redistribution
license was found in the retained artifact, and none is inferred. Retention in
this development repository is not a claim that an upstream work is freely
redistributable.

## International Telecommunication Union material

The publisher and rights holder identified by the PDFs and official catalogue
pages is the **International Telecommunication Union (ITU)** (historically
CCITT/CCIR). ITU's official pages state “All Rights Reserved”; the retained
copies therefore remain repository-only. Renderings and text extractions are
mechanical research derivatives of the named parent PDF. A derived rendering
or text extraction does not create or imply a redistribution grant for the
underlying ITU work.

| Retained artifact | SHA-256 | Source / derivation |
| --- | --- | --- |
| `tmp/pdfs/itu-r-m1677-1-2009.pdf` | `a3eab8884c24200f229ef20615ee3ae14329ba0f0a29c7a85a1eaa3cac442b97` | Exact retained download of ITU-R M.1677-1 (10/2009), from ITU's [official PDF endpoint](https://www.itu.int/dms_pubrec/itu-r/rec/m/R-REC-M.1677-1-200910-I!!PDF-E.pdf); owner/publisher: International Telecommunication Union. |
| `tmp/pdfs/itu-r-m1677-1-2009.txt` | `d5808a725d255794fa2eaa2a61e905b05a75e3d66a03340ef9bfd450c0995418` | Locally derived text extraction of `tmp/pdfs/itu-r-m1677-1-2009.pdf`. |
| `tmp/pdfs/m1677-render/page-2.png` | `e46083711e0cef5c5580da920b1d1ffb9a7640ef69df2e8fd9ad92bd5bff1191` | Locally derived rendering of page 2 of `tmp/pdfs/itu-r-m1677-1-2009.pdf`. |
| `tmp/pdfs/m1677-render/page-3.png` | `cf8bdf4a2ab216167bd3ec30c31d468f7683eba65730282a5a3a90c4832f4caf` | Locally derived rendering of page 3 of `tmp/pdfs/itu-r-m1677-1-2009.pdf`. |
| `tmp/pdfs/m1677-render/page-4.png` | `c6ad0a4a11f0bedfdf3e5333b1563a823780dd207a0f346efeaa8f5f81008d77` | Locally derived rendering of page 4 of `tmp/pdfs/itu-r-m1677-1-2009.pdf`. |
| `tmp/pdfs/m1677-render/page-5.png` | `2ebe863e44f52954865bcbfb1715eed13c37920fa382678028a71cd8ad2e6e69` | Locally derived rendering of page 5 of `tmp/pdfs/itu-r-m1677-1-2009.pdf`. |
| `tmp/pdfs/itu-t-t50-1992.pdf` | `849a6848640618846f4688c9f65884af1c54d51c9228141d9c13eec33f2a9c88` | Exact retained download of ITU-T T.50 (09/1992), from the [official recommendation record](https://www.itu.int/rec/T-REC-T.50-199209-I/en) and [official PDF endpoint](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-T.50-199209-I!!PDF-E&lang=e&type=items); owner/publisher: International Telecommunication Union. |
| `tmp/pdfs/itu-t-t50-1992.txt` | `ab6a9fd4232b5f6524470e459344ef3a621d5b3b88a1d91c55bc5e6ebc7501af` | Locally derived text extraction of `tmp/pdfs/itu-t-t50-1992.pdf`. |
| `tmp/pdfs/t50-render/page-07.png` | `b28b156f4fa4133ad55fc0eb8a4d110acf05ff94b5634b615e22e5a62f437519` | Locally derived rendering of page 7 of `tmp/pdfs/itu-t-t50-1992.pdf`. |
| `tmp/pdfs/t50-render/page-08.png` | `4f41467b929e24e68798db42f62fe72043a3dfb839fd6aea4d42d8fc54c0d848` | Locally derived rendering of page 8 of `tmp/pdfs/itu-t-t50-1992.pdf`. |
| `tmp/pdfs/t50-render/page-11.png` | `e37e452639c1ad3a1da0a1f37fed66ca18de11d6fcdaf1df0911d3a6937e27e1` | Locally derived rendering of page 11 of `tmp/pdfs/itu-t-t50-1992.pdf`. |
| `tmp/pdfs/t50-render/page-12.png` | `770f5b2c9320b42e9574e65523923089e28f8ef25bbfc176278daa4c187fcf6c` | Locally derived rendering of page 12 of `tmp/pdfs/itu-t-t50-1992.pdf`. |
| `tmp/pdfs/itu-t-s13-1988.pdf` | `d35f913490e1dbe972bf358cdc4e99a61f80ad66d4498990afc85955c85efc61` | The local filename is historical and misleading: PDF metadata and contents identify this as the 320-page **CCITT Orange Book, Volume VII (Geneva, 1976)**, containing Recommendation S.13 at PDF pages 133–134. Official origin: ITU's [VIth Plenary Assembly record](https://www.itu.int/en/history/Pages/AssemblyTelegraphTelephoneTelecommunication.aspx?conf=4.257), stable handle `11.1004/020.1000/4.257.43.en.1014`, and [official archive PDF](https://search.itu.int/history/HistoryDigitalCollectionDocLibrary/4.257.43.en.1014.pdf). The digest pins the retained scan because ITU archive reprocessing can change PDF bytes. Owner/publisher: International Telecommunication Union. |
| `tmp/pdfs/s13-render/page-133.png` | `0ccdee451f0d27c218009d5adf3eab8ecaaf4ac7ec2e125685a91e564ffd5eb2` | Locally derived rendering of page 133 of `tmp/pdfs/itu-t-s13-1988.pdf`. |
| `tmp/pdfs/s13-render/page-134.png` | `945aeaa593266805b331fc8663c07b6948f405407a04c43adb9882ebeab4abf5` | Locally derived rendering of page 134 of `tmp/pdfs/itu-t-s13-1988.pdf`. |
| `tmp/pdfs/telegraph-regulations-1949.pdf` | `3d1b13f97ebc9eeadc9cd123eb69b057e2091556c0d398a69a9747a59fe59287` | ITU Library and Archives scan titled “Documents of the International Telegraph and Telephone Conference (Paris, 1949) — Blue Pages (Telegraph Regulations)”. Official origin: the [1949 conference record](https://www.itu.int/en/history/Pages/TelegraphAndTelephoneConferences.aspx?conf=4.30), stable handle `11.1004/020.1000/4.30.51.en.106`, and [official archive PDF](https://search.itu.int/history/HistoryDigitalCollectionDocLibrary/4.30.51.en.106.pdf). Owner/publisher: International Telecommunication Union. |
| `tmp/pdfs/ita1-render/page-024.png` | `594785c881ffa43e07f1907b5e7633e2baf8472d7ed182731f80b3319568e684` | Locally cropped derived rendering of the International Telegraph Alphabet No. 1 table (Article 16) in `tmp/pdfs/telegraph-regulations-1949.pdf`. |
| `tmp/pdfs/telegraph-regulations-1958.pdf` | `3532cf74f0d2ce32b81e68fcd67c516f029799fcc19074f05a0c9240873589f9` | Exact retained ITU scan of the Telegraph Regulations (Geneva, 1958), from the [official conference record](https://www.itu.int/en/history/Pages/TelegraphAndTelephoneConferences.aspx?conf=4.31) and [official archive PDF](https://search.itu.int/history/HistoryDigitalCollectionDocLibrary/1.37.48.en.100.pdf); owner/publisher: International Telecommunication Union. |

## Other retained web captures

These are secondary research captures, not package inputs. Their presence does
not assert that the web-page layout, compilation, or cited source material is
under an open-source license.

| Retained artifact | SHA-256 | Source / ownership treatment |
| --- | --- | --- |
| `tmp/sources/baudot-derivates.html` | `40cb4b8b1e4d891ea7b3356588c913592fee617dff07413bdc7df99a777d1298` | Snapshot of the secondary table [“5-bit Teletypewriter Code / Baudot derivates”](https://dflund.se/~triad/krad/recode/baudot.html). The page names Steven J. Searle, Tom Jennings, and Alan G. Hobbs as sources but contains no author, copyright, or license grant for the HTML compilation. Ownership is therefore unresolved; repository-only. |
| `tmp/sources/mtk2-russian-order.html` | `57d20a87f3996f54f33a3410da70db02c89320faf1ddc0368b077e00e6c41c30` | Snapshot of [Kontur.Normativ's publication](https://normativ.kontur.ru/document?moduleId=1&documentId=235062) of Russian Ministry of Communications and Mass Media Order No. 15 of 29 January 2009 (as amended 23 April 2013), registered by the Ministry of Justice as No. 13437. The government legal text and Kontur page presentation have distinct ownership; the captured page gives no redistribution license. Repository-only. |

## Packaged normalized facts

`priv/sources/ibm-six-bit-transcode/` contains two original, normalized CSV
transcriptions and original metadata for IBM GA27-3005-3 and GA27-3004-2. The
metadata pins each primary manual's URL, byte size, SHA-256, and exact table
page. The CSVs contain only ordered unit/scalar facts and have SHA-256 values
`cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416`
and `5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e`.
The copyrighted IBM PDFs, their page layout, prose, and artwork are not
distributed. Tests prove the package includes the normalized evidence and no
raw PDF under `priv`.

## Packaging and verification policy

- `mix.exs` uses an explicit package allow-list and omits `tmp`, so these files
  are excluded from Hex archives.
- `test/source_provenance_contract_test.exs` recomputes every SHA-256 above and
  proves every retained file has a manifest entry.
- A built package, when present, is inspected to prove it has no `/tmp/` member.
- No redistribution license is inferred from public availability, standards
  status, government authorship, a historical scan, or local transformation.
