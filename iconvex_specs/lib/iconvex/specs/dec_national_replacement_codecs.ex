require Iconvex.Specs.DECNationalReplacementSets

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCUnitedKingdom,
  "DEC-NRC-UNITED-KINGDOM",
  ["BRITISH", "UNITED-KINGDOM-NRC", "UK-NRC", "DEC-UK-NRC"],
  :dec_nrc_united_kingdom,
  %{0x23 => 0x00A3}
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCDutch,
  "DEC-NRC-DUTCH",
  ["DUTCH", "DUTCH-NRC"],
  :dec_nrc_dutch,
  %{
    0x23 => 0x00A3,
    0x40 => 0x00BE,
    0x5B => 0x00FF,
    0x5C => 0x00BD,
    0x5D => 0x007C,
    0x7B => 0x00A8,
    0x7C => 0x0192,
    0x7D => 0x00BC,
    0x7E => 0x00B4
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCFinnish,
  "DEC-NRC-FINNISH",
  ["FINNISH", "FINNISH-NRC"],
  :dec_nrc_finnish,
  %{
    0x5B => 0x00C4,
    0x5C => 0x00D6,
    0x5D => 0x00C5,
    0x5E => 0x00DC,
    0x60 => 0x00E9,
    0x7B => 0x00E4,
    0x7C => 0x00F6,
    0x7D => 0x00E5,
    0x7E => 0x00FC
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCFrench,
  "DEC-NRC-FRENCH",
  ["FRENCH", "FRENCH-NRC"],
  :dec_nrc_french,
  %{
    0x23 => 0x00A3,
    0x40 => 0x00E0,
    0x5B => 0x00B0,
    0x5C => 0x00E7,
    0x5D => 0x00A7,
    0x7B => 0x00E9,
    0x7C => 0x00F9,
    0x7D => 0x00E8,
    0x7E => 0x00A8
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCFrenchCanadian,
  "DEC-NRC-FRENCH-CANADIAN",
  ["CANADIAN-FRENCH", "FRENCH-CANADIAN"],
  :dec_nrc_french_canadian,
  %{
    0x40 => 0x00E0,
    0x5B => 0x00E2,
    0x5C => 0x00E7,
    0x5D => 0x00EA,
    0x5E => 0x00EE,
    0x60 => 0x00F4,
    0x7B => 0x00E9,
    0x7C => 0x00F9,
    0x7D => 0x00E8,
    0x7E => 0x00FB
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCGerman,
  "DEC-NRC-GERMAN",
  ["GERMAN", "GERMAN-NRC"],
  :dec_nrc_german,
  %{
    0x40 => 0x00A7,
    0x5B => 0x00C4,
    0x5C => 0x00D6,
    0x5D => 0x00DC,
    0x7B => 0x00E4,
    0x7C => 0x00F6,
    0x7D => 0x00FC,
    0x7E => 0x00DF
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCItalian,
  "DEC-NRC-ITALIAN",
  ["ITALIAN", "ITALIAN-NRC"],
  :dec_nrc_italian,
  %{
    0x23 => 0x00A3,
    0x40 => 0x00A7,
    0x5B => 0x00B0,
    0x5C => 0x00E7,
    0x5D => 0x00E9,
    0x60 => 0x00F9,
    0x7B => 0x00E0,
    0x7C => 0x00F2,
    0x7D => 0x00E8,
    0x7E => 0x00EC
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCNorwegianDanish,
  "DEC-NRC-NORWEGIAN-DANISH",
  ["NORWEGIAN", "DANISH", "NORWEGIAN-DANISH"],
  :dec_nrc_norwegian_danish,
  %{
    0x5B => 0x00C6,
    0x5C => 0x00D8,
    0x5D => 0x00C5,
    0x7B => 0x00E6,
    0x7C => 0x00F8,
    0x7D => 0x00E5
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCPortuguese,
  "DEC-NRC-PORTUGUESE",
  ["PORTUGUESE", "PORTUGUESE-NRC"],
  :dec_nrc_portuguese,
  %{
    0x5B => 0x00C3,
    0x5C => 0x00C7,
    0x5D => 0x00D5,
    0x7B => 0x00E3,
    0x7C => 0x00E7,
    0x7D => 0x00F5
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCSpanish,
  "DEC-NRC-SPANISH",
  ["SPANISH", "SPANISH-NRC"],
  :dec_nrc_spanish,
  %{
    0x23 => 0x00A3,
    0x40 => 0x00A7,
    0x5B => 0x00A1,
    0x5C => 0x00D1,
    0x5D => 0x00BF,
    0x7B => 0x00B0,
    0x7C => 0x00F1,
    0x7D => 0x00E7
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCSwedish,
  "DEC-NRC-SWEDISH",
  ["SWEDISH", "SWEDISH-NRC"],
  :dec_nrc_swedish,
  %{
    0x40 => 0x00C9,
    0x5B => 0x00C4,
    0x5C => 0x00D6,
    0x5D => 0x00C5,
    0x5E => 0x00DC,
    0x60 => 0x00E9,
    0x7B => 0x00E4,
    0x7C => 0x00F6,
    0x7D => 0x00E5,
    0x7E => 0x00FC
  }
)

Iconvex.Specs.DECNationalReplacementSets.defcodec(
  Iconvex.Specs.DECNRCSwiss,
  "DEC-NRC-SWISS",
  ["SWISS", "SWISS-NRC"],
  :dec_nrc_swiss,
  %{
    0x23 => 0x00F9,
    0x40 => 0x00E0,
    0x5B => 0x00E9,
    0x5C => 0x00E7,
    0x5D => 0x00EA,
    0x5E => 0x00EE,
    0x5F => 0x00E8,
    0x60 => 0x00F4,
    0x7B => 0x00E4,
    0x7C => 0x00F6,
    0x7D => 0x00FC,
    0x7E => 0x00FB
  }
)
