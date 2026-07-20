defmodule Iconvex.Specs do
  @moduledoc "Public-specification codecs for Iconvex."

  @gnu_conflicting_rfc1345_names ~w(
    IBM037 IBM1026 IBM273 IBM277 IBM278 IBM280 IBM284 IBM285 IBM297 IBM424
    IBM437 IBM500 IBM852 IBM855 IBM857 IBM860 IBM861 IBM863 IBM864 IBM865
    IBM869 IBM870 IBM871 IBM880 IBM905
  )

  @type registration :: %{
          codec: module(),
          canonical: String.t(),
          aliases: [String.t()],
          declared_canonical: String.t(),
          source: String.t()
        }

  def rfc1345_codecs, do: Iconvex.Specs.RFC1345.Codecs.modules()
  def vendor_codecs, do: Iconvex.Specs.VendorMappings.Codecs.modules()

  @doc "Returns source-qualified single-property-token mappings (not byte-stream codecs)."
  def property_token_mappings do
    [
      Iconvex.Specs.Unihan17MainlandTelegraphDecimalToken,
      Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenReadable,
      Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenLosslessVPUA1,
      Iconvex.Specs.Unihan17KGB3RowCellDecimalToken
    ]
  end

  def supported_rfc1345_codecs do
    Iconvex.Specs.RFC1345.encodings()
    |> Enum.zip(rfc1345_codecs())
    |> Enum.reject(fn {entry, _codec} -> entry.unresolved_spec_positions > 0 end)
    |> Enum.map(fn {_entry, codec} -> codec end)
  end

  def codecs,
    do:
      supported_rfc1345_codecs() ++
        vendor_codecs() ++
        glibc_charmap_codecs() ++
        icu_ucm_codecs() ++
        icu_multibyte_codecs() ++
        icu_ebcdic_stateful_codecs() ++
        icu_archive_codecs() ++
        icu_swap_lfnl_codecs() ++
        windows_best_fit_codecs() ++
        unicode_legacy_codecs() ++
        unicode_mapping_component_codecs() ++
        unicode_misc_codecs() ++
        iso_ir_modern_codecs() ++
        iso_ir_cns11643_codecs() ++
        iso_ir_jisx0213_codecs() ++
        kps9566_97_codecs() ++
        iso_ir_mosaic_technical_codecs() ++
        iso_ir_historical_graphic_codecs() ++
        iana_pcl_symbol_set_codecs() ++
        evertype_source_qualified_codecs() ++
        lietuvybe_source_qualified_codecs() ++
        vietunicode_vni_codecs() ++
        secondary_source_qualified_single_byte_codecs() ++
        glyph_vector_unicode_codecs() ++
        tace16_transport_codecs() ++ additional_codecs()

  def catalogued_codecs,
    do:
      rfc1345_codecs() ++
        vendor_codecs() ++
        glibc_charmap_codecs() ++
        icu_ucm_codecs() ++
        icu_multibyte_codecs() ++
        icu_ebcdic_stateful_codecs() ++
        icu_archive_codecs() ++
        icu_swap_lfnl_codecs() ++
        windows_best_fit_codecs() ++
        unicode_legacy_codecs() ++
        unicode_mapping_component_codecs() ++
        unicode_misc_codecs() ++
        iso_ir_modern_codecs() ++
        iso_ir_cns11643_codecs() ++
        iso_ir_jisx0213_codecs() ++
        kps9566_97_codecs() ++
        iso_ir_mosaic_technical_codecs() ++
        iso_ir_historical_graphic_codecs() ++
        iana_pcl_symbol_set_codecs() ++
        evertype_source_qualified_codecs() ++
        lietuvybe_source_qualified_codecs() ++
        vietunicode_vni_codecs() ++
        secondary_source_qualified_single_byte_codecs() ++
        glyph_vector_unicode_codecs() ++
        tace16_transport_codecs() ++ additional_codecs()

  @doc "Returns the exact collision-safe identities installed in Iconvex's registry."
  @spec registrations() :: [registration()]
  def registrations do
    [
      entry_registrations(
        "RFC1345",
        Iconvex.Specs.RFC1345.encodings(),
        rfc1345_codecs(),
        &(&1.unresolved_spec_positions == 0),
        &rfc_aliases/1
      ),
      entry_registrations(
        &"UNICODE-#{String.upcase(&1.vendor, :ascii)}",
        Iconvex.Specs.VendorMappings.encodings(),
        vendor_codecs()
      ),
      entry_registrations(
        "GLIBC",
        Iconvex.Specs.GlibcCharmaps.encodings(),
        glibc_charmap_codecs()
      ),
      entry_registrations("ICU-UCM", Iconvex.Specs.ICUUCM.encodings(), icu_ucm_codecs()),
      entry_registrations(
        "ICU-MULTIBYTE",
        Iconvex.Specs.ICUMultibyte.encodings(),
        icu_multibyte_codecs()
      ),
      entry_registrations(
        "ICU-EBCDIC-STATEFUL",
        Iconvex.Specs.ICUEBCDICStateful.encodings(),
        icu_ebcdic_stateful_codecs()
      ),
      entry_registrations(
        "ICU-ARCHIVE",
        Iconvex.Specs.ICUArchive.encodings(),
        icu_archive_codecs()
      ),
      entry_registrations(
        "ICU-SWAP-LFNL",
        Iconvex.Specs.ICUSwapLFNL.encodings(),
        icu_swap_lfnl_codecs()
      ),
      entry_registrations(
        "WINDOWS-BEST-FIT",
        Iconvex.Specs.WindowsBestFit.encodings(),
        windows_best_fit_codecs()
      ),
      entry_registrations(
        "UNICODE-LEGACY",
        Iconvex.Specs.UnicodeLegacyMappings.encodings(),
        unicode_legacy_codecs()
      ),
      entry_registrations(
        "UNICODE-COMPONENT",
        Iconvex.Specs.UnicodeMappingComponents.encodings(),
        unicode_mapping_component_codecs()
      ),
      entry_registrations(
        "UNICODE-MISC",
        Iconvex.Specs.UnicodeMisc.encodings(),
        unicode_misc_codecs()
      ),
      entry_registrations(
        "ISO-IR-MODERN",
        Iconvex.Specs.ISOIRModern.encodings(),
        iso_ir_modern_codecs()
      ),
      entry_registrations(
        "ISO-IR-CNS11643",
        Iconvex.Specs.ISOIRCNS11643.encodings(),
        iso_ir_cns11643_codecs()
      ),
      entry_registrations(
        "ISO-IR-JISX0213",
        Iconvex.Specs.ISOIRJISX0213.encodings(),
        iso_ir_jisx0213_codecs()
      ),
      entry_registrations(
        "KPS9566-97",
        Iconvex.Specs.KPS956697.encodings(),
        kps9566_97_codecs()
      ),
      entry_registrations(
        "ISO-IR-MOSAIC",
        Iconvex.Specs.ISOIRMosaicTechnical.encodings(),
        iso_ir_mosaic_technical_codecs()
      ),
      entry_registrations(
        "ISO-IR-HISTORICAL",
        Iconvex.Specs.ISOIRHistoricalGraphic.encodings(),
        iso_ir_historical_graphic_codecs()
      ),
      entry_registrations(
        "IANA-PCL",
        Iconvex.Specs.IANAPCLSymbolSets.encodings(),
        iana_pcl_symbol_set_codecs()
      ),
      module_registrations("EVERTYPE", evertype_source_qualified_codecs()),
      module_registrations("LIETUVYBE-COMMIT", lietuvybe_source_qualified_codecs()),
      module_registrations("VIETUNICODE-2002", vietunicode_vni_codecs()),
      module_registrations(
        "SECONDARY-SOURCE-QUALIFIED",
        secondary_source_qualified_single_byte_codecs()
      ),
      module_registrations("GLYPH-VECTOR", glyph_vector_unicode_codecs()),
      module_registrations("TAMILVU-2010", tace16_transport_codecs()),
      module_registrations("SPECS", additional_codecs())
    ]
    |> List.flatten()
    |> qualify_builtin_collisions()
    |> qualify_gnu_conflicting_rfc1345()
    |> retain_collision_free_aliases()
  end

  def glibc_charmap_codecs, do: Iconvex.Specs.GlibcCharmaps.Codecs.modules()
  def icu_ucm_codecs, do: Iconvex.Specs.ICUUCM.Codecs.modules()
  def icu_multibyte_codecs, do: Iconvex.Specs.ICUMultibyte.Codecs.modules()
  def icu_ebcdic_stateful_codecs, do: Iconvex.Specs.ICUEBCDICStateful.Codecs.modules()
  def icu_archive_codecs, do: Iconvex.Specs.ICUArchive.Codecs.modules()
  def icu_swap_lfnl_codecs, do: Iconvex.Specs.ICUSwapLFNL.Codecs.modules()
  def windows_best_fit_codecs, do: Iconvex.Specs.WindowsBestFit.Codecs.modules()
  def unicode_legacy_codecs, do: Iconvex.Specs.UnicodeLegacyMappings.Codecs.modules()

  def unicode_mapping_component_codecs,
    do: Iconvex.Specs.UnicodeMappingComponents.Codecs.modules()

  def unicode_misc_codecs, do: Iconvex.Specs.UnicodeMisc.Codecs.modules()
  def iso_ir_modern_codecs, do: Iconvex.Specs.ISOIRModern.Codecs.modules()
  def iso_ir_cns11643_codecs, do: Iconvex.Specs.ISOIRCNS11643.Codecs.modules()
  def iso_ir_jisx0213_codecs, do: Iconvex.Specs.ISOIRJISX0213.Codecs.modules()
  def kps9566_97_codecs, do: Iconvex.Specs.KPS956697.Codecs.modules()
  def iso_ir_mosaic_technical_codecs, do: Iconvex.Specs.ISOIRMosaicTechnical.Codecs.modules()
  def iso_ir_historical_graphic_codecs, do: Iconvex.Specs.ISOIRHistoricalGraphic.Codecs.modules()
  def iana_pcl_symbol_set_codecs, do: Iconvex.Specs.IANAPCLSymbolSets.Codecs.modules()

  def evertype_source_qualified_codecs,
    do: Iconvex.Specs.Evertype.Codecs.modules()

  def lietuvybe_source_qualified_codecs,
    do: Iconvex.Specs.Lietuvybe.Codecs.modules()

  def vietunicode_vni_codecs,
    do: [
      Iconvex.Specs.VietUnicodeVNI.ASCII2002,
      Iconvex.Specs.VietUnicodeVNI.ANSI2002,
      Iconvex.Specs.VietUnicodeVNI.Mac2002,
      Iconvex.Specs.VietUnicodeVNI.InternetMail2002
    ]

  def secondary_source_qualified_single_byte_codecs,
    do: Iconvex.Specs.SecondarySourceQualifiedSingleByte.Codecs.modules()

  def glyph_vector_unicode_codecs,
    do: Iconvex.Specs.GlyphVectorUnicode.Codecs.modules()

  def tace16_transport_codecs,
    do: Iconvex.Specs.TACE16AppendixD2010.transport_codecs()

  def ibm_24_26_logical_codecs do
    [
      Iconvex.Specs.IBM2426ArrangementA,
      Iconvex.Specs.IBM2426ArrangementB,
      Iconvex.Specs.IBM2426ArrangementC,
      Iconvex.Specs.IBM2426ArrangementD,
      Iconvex.Specs.IBM2426ArrangementE,
      Iconvex.Specs.IBM2426ArrangementF,
      Iconvex.Specs.IBM2426ArrangementG,
      Iconvex.Specs.IBM2426ArrangementH,
      Iconvex.Specs.IBM2426ArrangementJ,
      Iconvex.Specs.IBM2426ArrangementK
    ]
  end

  def ibm_24_26_transport_codecs do
    for logical <- ibm_24_26_logical_codecs(), codec <- logical.transport_codecs(), do: codec
  end

  def iowa_card_logical_codecs do
    [
      Iconvex.Specs.DEC026CardIowa824E61A9,
      Iconvex.Specs.DEC029CardIowa824E61A9,
      Iconvex.Specs.EBCDCardIowa824E61A9,
      Iconvex.Specs.GE600CardIowa824E61A9
    ]
  end

  def iowa_card_transport_codecs do
    for logical <- iowa_card_logical_codecs(), codec <- logical.transport_codecs(), do: codec
  end

  def non_octet_codecs do
    [
      Iconvex.Specs.DECRadix50PDP9,
      Iconvex.Specs.DECRadix50PDP10,
      Iconvex.Specs.UTF18,
      Iconvex.Specs.UTF9,
      Iconvex.Specs.IBM7040HReport,
      Iconvex.Specs.IBM7040HProgram,
      Iconvex.Specs.IBM1401Card,
      Iconvex.Specs.CDC167BCDHollerith1965,
      Iconvex.Specs.CDC6000StandardHollerith1970,
      Iconvex.Specs.BCDCDCIowa,
      Iconvex.Specs.IBM029CardIowa824E61A9
    ] ++ iowa_card_logical_codecs() ++ ibm_24_26_logical_codecs()
  end

  def non_octet_encodings, do: Enum.map(non_octet_codecs(), & &1.canonical_name())
  def packed_codecs, do: Iconvex.Specs.Packed.all_profiles()

  def additional_codecs do
    [
      Iconvex.Specs.ABC800CharacterMode1981,
      Iconvex.Specs.StanfordRFC698FormatEffector1975,
      Iconvex.Specs.StanfordRFC698HiddenGraphics1975,
      Iconvex.Specs.CESU8,
      Iconvex.Specs.BOCU1,
      Iconvex.Specs.Punycode,
      Iconvex.Specs.FormalSignWriting,
      Iconvex.Specs.IMAPUTF7,
      Iconvex.Specs.JavaModifiedUTF8,
      Iconvex.Specs.UTF8Sig,
      Iconvex.Specs.UTF8Mac,
      Iconvex.Specs.WTF8,
      Iconvex.Specs.MARC8,
      Iconvex.Specs.ANSEL,
      Iconvex.Specs.SCSU,
      Iconvex.Specs.UTFEBCDIC,
      Iconvex.Specs.XUserDefined,
      Iconvex.Specs.Mnemonic,
      Iconvex.Specs.Mnem,
      Iconvex.Specs.VIQR,
      Iconvex.Specs.UTF1,
      Iconvex.Specs.UTF5,
      Iconvex.Specs.UTF6,
      Iconvex.Specs.IBM7040HReport16BE,
      Iconvex.Specs.IBM7040HReport16LE,
      Iconvex.Specs.IBM7040HProgram16BE,
      Iconvex.Specs.IBM7040HProgram16LE,
      Iconvex.Specs.IBM1401Card16BE,
      Iconvex.Specs.IBM1401Card16LE,
      Iconvex.Specs.CDC167BCDHollerith1965_16BE,
      Iconvex.Specs.CDC167BCDHollerith1965_16LE,
      Iconvex.Specs.CDC6000StandardHollerith1970_16BE,
      Iconvex.Specs.CDC6000StandardHollerith1970_16LE,
      Iconvex.Specs.BCDCDCIowa16BE,
      Iconvex.Specs.BCDCDCIowa16LE,
      Iconvex.Specs.IBM029CardIowa824E61A9_16BE,
      Iconvex.Specs.IBM029CardIowa824E61A9_16LE,
      Iconvex.Specs.DEC026CardIowa824E61A9_16BE,
      Iconvex.Specs.DEC026CardIowa824E61A9_16LE,
      Iconvex.Specs.DEC029CardIowa824E61A9_16BE,
      Iconvex.Specs.DEC029CardIowa824E61A9_16LE,
      Iconvex.Specs.EBCDCardIowa824E61A9_16BE,
      Iconvex.Specs.EBCDCardIowa824E61A9_16LE,
      Iconvex.Specs.GE600CardIowa824E61A9_16BE,
      Iconvex.Specs.GE600CardIowa824E61A9_16LE,
      Iconvex.Specs.CDC612DisplayCode63,
      Iconvex.Specs.CDC612DisplayCode64,
      Iconvex.Specs.CDCDisplayCode63,
      Iconvex.Specs.CDCDisplayCode64,
      Iconvex.Specs.CDCDisplayCodeASCII63,
      Iconvex.Specs.CDCDisplayCodeASCII64,
      Iconvex.Specs.DECSpecial,
      Iconvex.Specs.DECSpecialGR,
      Iconvex.Specs.DECTechnical,
      Iconvex.Specs.DECTechnicalGR,
      Iconvex.Specs.SI960,
      Iconvex.Specs.DECHebrew8,
      Iconvex.Specs.DECSIXBIT,
      Iconvex.Specs.PDP1Concise1960InitialLower,
      Iconvex.Specs.PDP1Concise1960InitialUpper,
      Iconvex.Specs.PDP1FridenFPC81960InitialLower,
      Iconvex.Specs.PDP1FridenFPC81960InitialUpper,
      Iconvex.Specs.PDP1ConciseFIODEC1963InitialLower,
      Iconvex.Specs.PDP1ConciseFIODEC1963InitialUpper,
      Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialLower,
      Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialUpper,
      Iconvex.Specs.UNIVACIExpanded1959,
      Iconvex.Specs.UNIVACIExpanded1959LosslessVPUA,
      Iconvex.Specs.UNIVACIExpanded1959RawVPUA,
      Iconvex.Specs.UNIVACIExpanded1959OddParity7Bit,
      Iconvex.Specs.UNIVACIExpanded1959PaperTapeRow,
      Iconvex.Specs.TeXLiveOMLCMMI10ToUnicode2026,
      Iconvex.Specs.TeXLiveOMSCMSY10ToUnicode2026,
      Iconvex.Specs.CorkT1ECGlyph,
      Iconvex.Specs.CorkT1CMap10J,
      Iconvex.Specs.OT1CMap10J,
      Iconvex.Specs.OT1TTCMap10J,
      Iconvex.Specs.FieldataUNIVAC1100,
      Iconvex.Specs.FieldataUNIVAC4009Input,
      Iconvex.Specs.FieldataUNIVAC4009Output,
      Iconvex.Specs.FieldataUNIVAC4009LosslessVPUA,
      Iconvex.Specs.FieldataUNIVAC4009RawVPUA,
      Iconvex.Specs.TI89AMS20,
      Iconvex.Specs.TI89AMS20Visible,
      Iconvex.Specs.TI89AMS20LosslessVPUA,
      Iconvex.Specs.TI89AMS20RawVPUA,
      Iconvex.Specs.PASCII10UrduKashmiriBestFit,
      Iconvex.Specs.PASCII10SindhiBestFit,
      Iconvex.Specs.PASCII10LosslessVPUA1,
      Iconvex.Specs.PASCII10RawVPUA1,
      Iconvex.Specs.Unihan17KGB3RowCellGL,
      Iconvex.Specs.TI83PlusLarge,
      Iconvex.Specs.TI83PlusLargeLosslessVPUA,
      Iconvex.Specs.TI83PlusLargeRawVPUA,
      Iconvex.Specs.TI83PlusSmall,
      Iconvex.Specs.TI83PlusSmallLosslessVPUA,
      Iconvex.Specs.TI83PlusSmallRawVPUA,
      Iconvex.Specs.DECRadix50BE16,
      Iconvex.Specs.DECRadix50LE16,
      Iconvex.Specs.DECRadix50PDP9BE24,
      Iconvex.Specs.DECRadix50PDP9LE24,
      Iconvex.Specs.DECRadix50PDP10BE40,
      Iconvex.Specs.DECRadix50PDP10LE40,
      Iconvex.Specs.IBM310293P100CompositeVPUA,
      Iconvex.Specs.IBMTNZCP310B1EAE3C,
      Iconvex.Specs.IBM907CDRAP100VPUAComposite,
      Iconvex.Specs.IBM1116850P100Composite,
      Iconvex.Specs.IBM1117437P100Composite,
      Iconvex.Specs.DECGreek81994,
      Iconvex.Specs.DECTurkish81994,
      Iconvex.Specs.ECMA1,
      Iconvex.Specs.KOI7Switched,
      Iconvex.Specs.ShortKOI,
      Iconvex.Specs.KOI8F,
      Iconvex.Specs.KEYBCS2,
      Iconvex.Specs.MySQLKEYBCS2,
      Iconvex.Specs.ABICOMP,
      Iconvex.Specs.BraSCII,
      Iconvex.Specs.MacEsperanto,
      Iconvex.Specs.VSCII2,
      Iconvex.Specs.LotusLICS,
      Iconvex.Specs.USArmyTapCodePairValues,
      Iconvex.Specs.KermitELOT927Greek,
      Iconvex.Specs.KermitGreekISO,
      Iconvex.Specs.KermitHebrewISO,
      Iconvex.Specs.Latin6ISO,
      Iconvex.Specs.KermitMacintoshLatin,
      Iconvex.Specs.KermitBulgariaPC,
      Iconvex.Specs.KermitMazovia,
      Iconvex.Specs.KermitQNXConsole,
      Iconvex.Specs.KermitDGInternational,
      Iconvex.Specs.KermitDGLineDrawing,
      Iconvex.Specs.KermitDGWordProcessing,
      Iconvex.Specs.KermitHPMathTechnical,
      Iconvex.Specs.KermitSNIBrackets,
      Iconvex.Specs.KermitSNIEuro,
      Iconvex.Specs.KermitSNIFacet,
      Iconvex.Specs.KermitSNIIBM,
      Iconvex.Specs.KermitJIS7Kanji,
      Iconvex.Specs.DECNRCUnitedKingdom,
      Iconvex.Specs.DECNRCDutch,
      Iconvex.Specs.DECNRCFinnish,
      Iconvex.Specs.DECNRCFrench,
      Iconvex.Specs.DECNRCFrenchCanadian,
      Iconvex.Specs.DECNRCGerman,
      Iconvex.Specs.DECNRCItalian,
      Iconvex.Specs.DECNRCNorwegianDanish,
      Iconvex.Specs.DECNRCPortuguese,
      Iconvex.Specs.DECNRCSpanish,
      Iconvex.Specs.DECNRCSwedish,
      Iconvex.Specs.DECNRCSwiss,
      Iconvex.Specs.IconvexUTF32BESignature,
      Iconvex.Specs.IconvexUTF32LESignature,
      Iconvex.Specs.IconvexUTF16SignatureLEDefault,
      Iconvex.Specs.ICUUTF16PlatformEndian,
      Iconvex.Specs.ICUUTF16OppositeEndian,
      Iconvex.Specs.ICUUTF32PlatformEndian,
      Iconvex.Specs.ICUUTF32OppositeEndian,
      Iconvex.Specs.ICUUTF16Version1,
      Iconvex.Specs.ICUUTF16Version2,
      Iconvex.Specs.ICUJIS7,
      Iconvex.Specs.ICUJIS8,
      Iconvex.Specs.ICULMBCS1,
      Iconvex.Specs.ICULMBCS2,
      Iconvex.Specs.ICULMBCS3,
      Iconvex.Specs.ICULMBCS4,
      Iconvex.Specs.ICULMBCS5,
      Iconvex.Specs.ICULMBCS6,
      Iconvex.Specs.ICULMBCS8,
      Iconvex.Specs.ICULMBCS11,
      Iconvex.Specs.ICULMBCS16,
      Iconvex.Specs.ICULMBCS17,
      Iconvex.Specs.ICULMBCS18,
      Iconvex.Specs.ICULMBCS19,
      Iconvex.Specs.ICUCompoundText,
      Iconvex.Specs.DotnetXEuropa,
      Iconvex.Specs.MicrosoftCP51950,
      Iconvex.Specs.DotnetCP50227,
      Iconvex.Specs.IANAAmiga1251,
      Iconvex.Specs.IANAEUCFixedWidthJapanese,
      Iconvex.Specs.GlibcIBM423,
      Iconvex.Specs.CPythonISO2022JPExt,
      Iconvex.Specs.IBMUnicodeCCSIDs.Codec,
      Iconvex.Specs.IBM5052,
      Iconvex.Specs.IBM5053,
      Iconvex.Specs.IBM958,
      Iconvex.Specs.IBM5055,
      Iconvex.Specs.IBM965,
      Iconvex.Specs.IBM1175,
      Iconvex.Specs.IBM17354,
      Iconvex.Specs.IBM934,
      Iconvex.Specs.IBM938,
      Iconvex.Specs.UTF9BE16,
      Iconvex.Specs.UTF9LE16,
      Iconvex.Specs.UTF18BE24,
      Iconvex.Specs.UTF18LE24,
      Iconvex.Specs.ISOIR169,
      Iconvex.Specs.ISOIR42
    ] ++
      ibm_24_26_transport_codecs() ++
      Iconvex.Specs.LegacyComputingN5028.codecs() ++
      Iconvex.Specs.IANAISO10646Profiles.Codecs.modules() ++
      Iconvex.Specs.ISCII.Codecs.modules()
  end

  def encodings, do: Enum.map(registrations(), & &1.canonical)

  def catalogued_encodings do
    Enum.map(catalogued_codecs(), & &1.canonical_name())
  end

  defp entry_registrations(
         source,
         entries,
         codecs,
         include? \\ fn _entry -> true end,
         aliases \\ & &1.aliases
       ) do
    entries
    |> Enum.zip(codecs)
    |> Enum.filter(fn {entry, _codec} -> include?.(entry) end)
    |> Enum.map(fn {entry, codec} ->
      source = if is_function(source, 1), do: source.(entry), else: source

      %{
        codec: codec,
        source: source,
        declared_canonical: codec.canonical_name(),
        canonical: codec.canonical_name(),
        aliases: Enum.uniq(aliases.(entry) ++ codec.aliases())
      }
    end)
  end

  defp module_registrations(source, codecs) do
    Enum.map(codecs, fn codec ->
      %{
        codec: codec,
        source: source,
        declared_canonical: codec.canonical_name(),
        canonical: codec.canonical_name(),
        aliases: Enum.uniq(codec.aliases())
      }
    end)
  end

  defp qualify_builtin_collisions(registrations) do
    Enum.map(registrations, fn registration ->
      if match?(
           {:ok, _entry},
           Iconvex.Registry.builtin_resolve(registration.declared_canonical)
         ) do
        %{registration | canonical: "#{registration.source}:#{registration.declared_canonical}"}
      else
        registration
      end
    end)
  end

  defp qualify_gnu_conflicting_rfc1345(registrations) do
    Enum.map(registrations, fn
      %{source: "RFC1345", declared_canonical: declared_canonical} = registration
      when declared_canonical in @gnu_conflicting_rfc1345_names ->
        %{
          registration
          | canonical: "RFC1345:#{declared_canonical}",
            aliases: Enum.map(registration.aliases, &"RFC1345:#{&1}")
        }

      registration ->
        registration
    end)
  end

  defp retain_collision_free_aliases(registrations) do
    claimed =
      registrations
      |> Enum.map(&normalize(&1.canonical))
      |> MapSet.new()

    {registrations, _claimed} =
      Enum.map_reduce(registrations, claimed, fn registration, claimed ->
        aliases =
          registration.aliases
          |> Enum.uniq_by(&normalize/1)
          |> Enum.reject(fn alias_name ->
            normalized = normalize(alias_name)

            MapSet.member?(claimed, normalized) or
              match?({:ok, _entry}, Iconvex.Registry.builtin_resolve(alias_name))
          end)

        claimed = Enum.reduce(aliases, claimed, &MapSet.put(&2, normalize(&1)))
        {%{registration | aliases: aliases}, claimed}
      end)

    registrations
  end

  defp rfc_aliases(%{name: "greek7", aliases: aliases}),
    do: aliases ++ ["ELOT-927", "ELOT927"]

  defp rfc_aliases(%{name: "MSZ_7795.3", aliases: aliases}),
    do: aliases ++ ["HUNGARIAN"]

  defp rfc_aliases(%{aliases: aliases}), do: aliases

  defp normalize(name), do: String.upcase(name, :ascii)
end
