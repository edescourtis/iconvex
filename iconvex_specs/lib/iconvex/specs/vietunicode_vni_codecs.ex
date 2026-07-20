require Iconvex.Specs.VietUnicodeVNI

Iconvex.Specs.VietUnicodeVNI.defcodec(
  Iconvex.Specs.VietUnicodeVNI.ASCII2002,
  profile: :ascii,
  canonical: "VIETUNICODE-2002-VNI-ASCII-DOS",
  aliases: ["ENCODE-VN-0.06-X-VIET-VNI-ASCII"],
  codec_id: :vietunicode_2002_vni_ascii_dos,
  mapping_count: 255,
  max_token_bytes: 1,
  unit_model: :single_byte_font_glyph_profile,
  sequence_round_trip: :all_mapped_scalar_sequences
)

Iconvex.Specs.VietUnicodeVNI.defcodec(
  Iconvex.Specs.VietUnicodeVNI.ANSI2002,
  profile: :ansi,
  canonical: "VIETUNICODE-2002-VNI-ANSI-WIN-UNIX",
  aliases: ["ENCODE-VN-0.06-X-VIET-VNI"],
  codec_id: :vietunicode_2002_vni_ansi,
  mapping_count: 262,
  max_token_bytes: 2,
  unit_model: :one_or_two_byte_token_encoding,
  sequence_round_trip: :all_mapped_scalar_sequences
)

Iconvex.Specs.VietUnicodeVNI.defcodec(
  Iconvex.Specs.VietUnicodeVNI.Mac2002,
  profile: :mac,
  canonical: "VIETUNICODE-2002-VNI-MAC",
  aliases: ["ENCODE-VN-0.06-X-VIET-VNI-MAC"],
  codec_id: :vietunicode_2002_vni_mac,
  mapping_count: 262,
  max_token_bytes: 2,
  unit_model: :one_or_two_byte_token_encoding,
  sequence_round_trip: :all_mapped_scalar_sequences
)

Iconvex.Specs.VietUnicodeVNI.defcodec(
  Iconvex.Specs.VietUnicodeVNI.InternetMail2002,
  profile: :email,
  canonical: "VIETUNICODE-2002-VNI-INTERNET-MAIL",
  aliases: ["ENCODE-VN-0.06-X-VIET-VNI-EMAIL"],
  codec_id: :vietunicode_2002_vni_internet_mail,
  mapping_count: 262,
  max_token_bytes: 3,
  unit_model: :one_to_three_byte_font_token_profile,
  sequence_round_trip: :not_injective_across_token_boundaries
)
