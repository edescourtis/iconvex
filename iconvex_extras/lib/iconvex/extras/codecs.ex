defmodule Iconvex.Extras.Codecs do
  @moduledoc false
  @modules [
    Iconvex.Extras.Codecs.Atarist,
    Iconvex.Extras.Codecs.Big52003,
    Iconvex.Extras.Codecs.Cp1046,
    Iconvex.Extras.Codecs.Cp1124,
    Iconvex.Extras.Codecs.Cp1125,
    Iconvex.Extras.Codecs.Cp1129,
    Iconvex.Extras.Codecs.Cp1161,
    Iconvex.Extras.Codecs.Cp1162,
    Iconvex.Extras.Codecs.Cp1163,
    Iconvex.Extras.Codecs.Cp437,
    Iconvex.Extras.Codecs.Cp737,
    Iconvex.Extras.Codecs.Cp775,
    Iconvex.Extras.Codecs.Cp852,
    Iconvex.Extras.Codecs.Cp853,
    Iconvex.Extras.Codecs.Cp855,
    Iconvex.Extras.Codecs.Cp856,
    Iconvex.Extras.Codecs.Cp857,
    Iconvex.Extras.Codecs.Cp858,
    Iconvex.Extras.Codecs.Cp860,
    Iconvex.Extras.Codecs.Cp861,
    Iconvex.Extras.Codecs.Cp863,
    Iconvex.Extras.Codecs.Cp864,
    Iconvex.Extras.Codecs.Cp865,
    Iconvex.Extras.Codecs.Cp869,
    Iconvex.Extras.Codecs.Cp922,
    Iconvex.Extras.Codecs.Cp943,
    Iconvex.Extras.Codecs.DecHanyu,
    Iconvex.Extras.Codecs.DecKanji,
    Iconvex.Extras.Codecs.EucJisx0213,
    Iconvex.Extras.Codecs.Ebcdic037,
    Iconvex.Extras.Codecs.Ebcdic1025,
    Iconvex.Extras.Codecs.Ebcdic1026,
    Iconvex.Extras.Codecs.Ebcdic1047,
    Iconvex.Extras.Codecs.Ebcdic1097,
    Iconvex.Extras.Codecs.Ebcdic1112,
    Iconvex.Extras.Codecs.Ebcdic1122,
    Iconvex.Extras.Codecs.Ebcdic1123,
    Iconvex.Extras.Codecs.Ebcdic1130,
    Iconvex.Extras.Codecs.Ebcdic1132,
    Iconvex.Extras.Codecs.Ebcdic1137,
    Iconvex.Extras.Codecs.Ebcdic1140,
    Iconvex.Extras.Codecs.Ebcdic1141,
    Iconvex.Extras.Codecs.Ebcdic1142,
    Iconvex.Extras.Codecs.Ebcdic1143,
    Iconvex.Extras.Codecs.Ebcdic1144,
    Iconvex.Extras.Codecs.Ebcdic1145,
    Iconvex.Extras.Codecs.Ebcdic1146,
    Iconvex.Extras.Codecs.Ebcdic1147,
    Iconvex.Extras.Codecs.Ebcdic1148,
    Iconvex.Extras.Codecs.Ebcdic1149,
    Iconvex.Extras.Codecs.Ebcdic1153,
    Iconvex.Extras.Codecs.Ebcdic1154,
    Iconvex.Extras.Codecs.Ebcdic1155,
    Iconvex.Extras.Codecs.Ebcdic1156,
    Iconvex.Extras.Codecs.Ebcdic1157,
    Iconvex.Extras.Codecs.Ebcdic1158,
    Iconvex.Extras.Codecs.Ebcdic1160,
    Iconvex.Extras.Codecs.Ebcdic1164,
    Iconvex.Extras.Codecs.Ebcdic1165,
    Iconvex.Extras.Codecs.Ebcdic1166,
    Iconvex.Extras.Codecs.Ebcdic12712,
    Iconvex.Extras.Codecs.Ebcdic16804,
    Iconvex.Extras.Codecs.Ebcdic273,
    Iconvex.Extras.Codecs.Ebcdic277,
    Iconvex.Extras.Codecs.Ebcdic278,
    Iconvex.Extras.Codecs.Ebcdic280,
    Iconvex.Extras.Codecs.Ebcdic282,
    Iconvex.Extras.Codecs.Ebcdic284,
    Iconvex.Extras.Codecs.Ebcdic285,
    Iconvex.Extras.Codecs.Ebcdic297,
    Iconvex.Extras.Codecs.Ebcdic423,
    Iconvex.Extras.Codecs.Ebcdic424,
    Iconvex.Extras.Codecs.Ebcdic425,
    Iconvex.Extras.Codecs.Ebcdic4971,
    Iconvex.Extras.Codecs.Ebcdic500,
    Iconvex.Extras.Codecs.Ebcdic838,
    Iconvex.Extras.Codecs.Ebcdic870,
    Iconvex.Extras.Codecs.Ebcdic871,
    Iconvex.Extras.Codecs.Ebcdic875,
    Iconvex.Extras.Codecs.Ebcdic880,
    Iconvex.Extras.Codecs.Ebcdic905,
    Iconvex.Extras.Codecs.Ebcdic924,
    Iconvex.Extras.Codecs.Iso2022Jp3,
    Iconvex.Extras.Codecs.Riscos1,
    Iconvex.Extras.Codecs.ShiftJisx0213,
    Iconvex.Extras.Codecs.Tds565
  ]
  def modules, do: @modules
end

defmodule Iconvex.Extras.Codecs.Atarist do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "ATARIST"

  @impl true
  def aliases, do: ["ATARI"]

  @impl true
  def codec_id, do: :atarist

  @impl true
  def decode(input), do: CodecSupport.decode(:atarist, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:atarist, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:atarist, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:atarist, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:atarist, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:atarist, input)
end

defmodule Iconvex.Extras.Codecs.Big52003 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "BIG5-2003"

  @impl true
  def aliases, do: []

  @impl true
  def codec_id, do: :big5_2003

  @impl true
  def decode(input), do: CodecSupport.decode(:big5_2003, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:big5_2003, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:big5_2003, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:big5_2003, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:big5_2003, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:big5_2003, input)
end

defmodule Iconvex.Extras.Codecs.Cp1046 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1046"

  @impl true
  def aliases, do: ["IBM-1046"]

  @impl true
  def codec_id, do: :cp1046

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1046, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1046, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1046, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1046, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1046, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1046, input)
end

defmodule Iconvex.Extras.Codecs.Cp1124 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1124"

  @impl true
  def aliases, do: ["IBM-1124"]

  @impl true
  def codec_id, do: :cp1124

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1124, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1124, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1124, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1124, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1124, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1124, input)
end

defmodule Iconvex.Extras.Codecs.Cp1125 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1125"

  @impl true
  def aliases, do: ["IBM-1125"]

  @impl true
  def codec_id, do: :cp1125

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1125, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1125, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1125, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1125, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1125, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1125, input)
end

defmodule Iconvex.Extras.Codecs.Cp1129 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1129"

  @impl true
  def aliases, do: ["IBM-1129"]

  @impl true
  def codec_id, do: :cp1129

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1129, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1129, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1129, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1129, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1129, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1129, input)
end

defmodule Iconvex.Extras.Codecs.Cp1161 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1161"

  @impl true
  def aliases, do: ["CSIBM1161", "IBM-1161", "IBM1161"]

  @impl true
  def codec_id, do: :cp1161

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1161, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1161, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1161, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1161, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1161, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1161, input)
end

defmodule Iconvex.Extras.Codecs.Cp1162 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1162"

  @impl true
  def aliases, do: ["CSIBM1162", "IBM-1162", "IBM1162"]

  @impl true
  def codec_id, do: :cp1162

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1162, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1162, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1162, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1162, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1162, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1162, input)
end

defmodule Iconvex.Extras.Codecs.Cp1163 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP1163"

  @impl true
  def aliases, do: ["CSIBM1163", "IBM-1163", "IBM1163"]

  @impl true
  def codec_id, do: :cp1163

  @impl true
  def decode(input), do: CodecSupport.decode(:cp1163, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp1163, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp1163, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp1163, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp1163, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp1163, input)
end

defmodule Iconvex.Extras.Codecs.Cp437 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP437"

  @impl true
  def aliases, do: ["437", "CSPC8CODEPAGE437", "IBM-437", "IBM437"]

  @impl true
  def codec_id, do: :cp437

  @impl true
  def decode(input), do: CodecSupport.decode(:cp437, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp437, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp437, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp437, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp437, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp437, input)
end

defmodule Iconvex.Extras.Codecs.Cp737 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP737"

  @impl true
  def aliases, do: []

  @impl true
  def codec_id, do: :cp737

  @impl true
  def decode(input), do: CodecSupport.decode(:cp737, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp737, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp737, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp737, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp737, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp737, input)
end

defmodule Iconvex.Extras.Codecs.Cp775 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP775"

  @impl true
  def aliases, do: ["CSPC775BALTIC", "IBM775"]

  @impl true
  def codec_id, do: :cp775

  @impl true
  def decode(input), do: CodecSupport.decode(:cp775, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp775, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp775, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp775, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp775, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp775, input)
end

defmodule Iconvex.Extras.Codecs.Cp852 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP852"

  @impl true
  def aliases, do: ["852", "CSPCP852", "IBM-852", "IBM852"]

  @impl true
  def codec_id, do: :cp852

  @impl true
  def decode(input), do: CodecSupport.decode(:cp852, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp852, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp852, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp852, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp852, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp852, input)
end

defmodule Iconvex.Extras.Codecs.Cp853 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP853"

  @impl true
  def aliases, do: []

  @impl true
  def codec_id, do: :cp853

  @impl true
  def decode(input), do: CodecSupport.decode(:cp853, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp853, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp853, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp853, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp853, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp853, input)
end

defmodule Iconvex.Extras.Codecs.Cp855 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP855"

  @impl true
  def aliases, do: ["855", "CSIBM855", "IBM-855", "IBM855"]

  @impl true
  def codec_id, do: :cp855

  @impl true
  def decode(input), do: CodecSupport.decode(:cp855, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp855, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp855, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp855, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp855, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp855, input)
end

defmodule Iconvex.Extras.Codecs.Cp856 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP856"

  @impl true
  def aliases, do: ["IBM-856"]

  @impl true
  def codec_id, do: :cp856

  @impl true
  def decode(input), do: CodecSupport.decode(:cp856, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp856, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp856, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp856, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp856, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp856, input)
end

defmodule Iconvex.Extras.Codecs.Cp857 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP857"

  @impl true
  def aliases, do: ["857", "CSIBM857", "IBM-857", "IBM857"]

  @impl true
  def codec_id, do: :cp857

  @impl true
  def decode(input), do: CodecSupport.decode(:cp857, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp857, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp857, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp857, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp857, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp857, input)
end

defmodule Iconvex.Extras.Codecs.Cp858 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP858"

  @impl true
  def aliases, do: []

  @impl true
  def codec_id, do: :cp858

  @impl true
  def decode(input), do: CodecSupport.decode(:cp858, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp858, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp858, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp858, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp858, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp858, input)
end

defmodule Iconvex.Extras.Codecs.Cp860 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP860"

  @impl true
  def aliases, do: ["860", "CSIBM860", "IBM-860", "IBM860"]

  @impl true
  def codec_id, do: :cp860

  @impl true
  def decode(input), do: CodecSupport.decode(:cp860, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp860, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp860, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp860, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp860, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp860, input)
end

defmodule Iconvex.Extras.Codecs.Cp861 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP861"

  @impl true
  def aliases, do: ["861", "CP-IS", "CSIBM861", "IBM-861", "IBM861"]

  @impl true
  def codec_id, do: :cp861

  @impl true
  def decode(input), do: CodecSupport.decode(:cp861, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp861, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp861, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp861, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp861, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp861, input)
end

defmodule Iconvex.Extras.Codecs.Cp863 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP863"

  @impl true
  def aliases, do: ["863", "CSIBM863", "IBM-863", "IBM863"]

  @impl true
  def codec_id, do: :cp863

  @impl true
  def decode(input), do: CodecSupport.decode(:cp863, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp863, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp863, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp863, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp863, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp863, input)
end

defmodule Iconvex.Extras.Codecs.Cp864 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP864"

  @impl true
  def aliases, do: ["CSIBM864", "IBM-864", "IBM864"]

  @impl true
  def codec_id, do: :cp864

  @impl true
  def decode(input), do: CodecSupport.decode(:cp864, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp864, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp864, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp864, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp864, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp864, input)
end

defmodule Iconvex.Extras.Codecs.Cp865 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP865"

  @impl true
  def aliases, do: ["865", "CSIBM865", "IBM-865", "IBM865"]

  @impl true
  def codec_id, do: :cp865

  @impl true
  def decode(input), do: CodecSupport.decode(:cp865, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp865, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp865, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp865, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp865, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp865, input)
end

defmodule Iconvex.Extras.Codecs.Cp869 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP869"

  @impl true
  def aliases, do: ["869", "CP-GR", "CSIBM869", "IBM-869", "IBM869"]

  @impl true
  def codec_id, do: :cp869

  @impl true
  def decode(input), do: CodecSupport.decode(:cp869, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp869, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp869, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp869, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp869, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp869, input)
end

defmodule Iconvex.Extras.Codecs.Cp922 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP922"

  @impl true
  def aliases, do: ["IBM-922"]

  @impl true
  def codec_id, do: :cp922

  @impl true
  def decode(input), do: CodecSupport.decode(:cp922, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp922, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp922, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp922, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp922, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp922, input)
end

defmodule Iconvex.Extras.Codecs.Cp943 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "CP943"

  @impl true
  def aliases, do: ["IBM-943", "SJIS-1", "SJIS-2"]

  @impl true
  def codec_id, do: :cp943

  @impl true
  def decode(input), do: CodecSupport.decode(:cp943, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:cp943, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:cp943, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:cp943, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:cp943, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:cp943, input)
end

defmodule Iconvex.Extras.Codecs.DecHanyu do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "DEC-HANYU"

  @impl true
  def aliases, do: ["DECHANYU"]

  @impl true
  def codec_id, do: :dec_hanyu

  @impl true
  def decode(input), do: CodecSupport.decode(:dec_hanyu, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:dec_hanyu, input)

  @impl true
  def decode_error_consumption(:incomplete_sequence, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  def decode_error_consumption(_kind, _sequence), do: 1

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:dec_hanyu, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:dec_hanyu, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:dec_hanyu, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:dec_hanyu, input)
end

defmodule Iconvex.Extras.Codecs.DecKanji do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "DEC-KANJI"

  @impl true
  def aliases, do: ["DECKANJI"]

  @impl true
  def codec_id, do: :dec_kanji

  @impl true
  def decode(input), do: CodecSupport.decode(:dec_kanji, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:dec_kanji, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:dec_kanji, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:dec_kanji, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:dec_kanji, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:dec_kanji, input)
end

defmodule Iconvex.Extras.Codecs.EucJisx0213 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "EUC-JISX0213"

  @impl true
  def aliases, do: ["EUC-JIS-2004"]

  @impl true
  def codec_id, do: :euc_jisx0213

  @impl true
  def decode(input), do: CodecSupport.decode(:euc_jisx0213, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:euc_jisx0213, input)

  @impl true
  def decode_error_consumption(:incomplete_sequence, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  def decode_error_consumption(_kind, _sequence), do: 1

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:euc_jisx0213, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:euc_jisx0213, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:euc_jisx0213, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:euc_jisx0213, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic037 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-037"

  @impl true
  def aliases,
    do: [
      "CP037",
      "CSIBM037",
      "EBCDIC-CP-CA",
      "EBCDIC-CP-NL",
      "EBCDIC-CP-US",
      "EBCDIC-CP-WT",
      "IBM037"
    ]

  @impl true
  def codec_id, do: :ebcdic037

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic037, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic037, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic037, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic037, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic037, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic037, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1025 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1025"

  @impl true
  def aliases, do: ["CP1025", "IBM1025"]

  @impl true
  def codec_id, do: :ebcdic1025

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1025, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1025, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1025, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1025, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1025, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1025, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1026 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1026"

  @impl true
  def aliases, do: ["CP1026", "CSIBM1026", "IBM1026"]

  @impl true
  def codec_id, do: :ebcdic1026

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1026, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1026, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1026, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1026, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1026, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1026, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1047 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1047"

  @impl true
  def aliases, do: ["CP1047", "CSIBM1047", "IBM1047"]

  @impl true
  def codec_id, do: :ebcdic1047

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1047, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1047, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1047, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1047, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1047, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1047, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1097 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1097"

  @impl true
  def aliases, do: ["CP1097", "IBM1097"]

  @impl true
  def codec_id, do: :ebcdic1097

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1097, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1097, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1097, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1097, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1097, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1097, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1112 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1112"

  @impl true
  def aliases, do: ["CP1112", "IBM1112"]

  @impl true
  def codec_id, do: :ebcdic1112

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1112, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1112, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1112, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1112, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1112, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1112, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1122 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1122"

  @impl true
  def aliases, do: ["CP1122", "IBM1122"]

  @impl true
  def codec_id, do: :ebcdic1122

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1122, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1122, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1122, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1122, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1122, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1122, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1123 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1123"

  @impl true
  def aliases, do: ["CP1123", "IBM1123"]

  @impl true
  def codec_id, do: :ebcdic1123

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1123, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1123, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1123, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1123, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1123, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1123, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1130 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1130"

  @impl true
  def aliases, do: ["CP1130", "IBM1130"]

  @impl true
  def codec_id, do: :ebcdic1130

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1130, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1130, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1130, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1130, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1130, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1130, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1132 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1132"

  @impl true
  def aliases, do: ["CP1132", "IBM1132"]

  @impl true
  def codec_id, do: :ebcdic1132

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1132, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1132, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1132, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1132, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1132, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1132, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1137 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1137"

  @impl true
  def aliases, do: ["CP1137", "IBM1137"]

  @impl true
  def codec_id, do: :ebcdic1137

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1137, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1137, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1137, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1137, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1137, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1137, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1140 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1140"

  @impl true
  def aliases,
    do: ["CCSID01140", "CP01140", "CSIBM01140", "EBCDIC-US-37+EURO", "IBM01140", "IBM1140"]

  @impl true
  def codec_id, do: :ebcdic1140

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1140, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1140, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1140, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1140, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1140, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1140, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1141 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1141"

  @impl true
  def aliases,
    do: ["CCSID01141", "CP01141", "CSIBM01141", "EBCDIC-DE-273+EURO", "IBM01141", "IBM1141"]

  @impl true
  def codec_id, do: :ebcdic1141

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1141, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1141, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1141, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1141, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1141, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1141, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1142 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1142"

  @impl true
  def aliases,
    do: [
      "CCSID01142",
      "CP01142",
      "CSIBM01142",
      "EBCDIC-DK-277+EURO",
      "EBCDIC-NO-277+EURO",
      "IBM01142",
      "IBM1142"
    ]

  @impl true
  def codec_id, do: :ebcdic1142

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1142, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1142, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1142, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1142, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1142, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1142, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1143 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1143"

  @impl true
  def aliases,
    do: [
      "CCSID01143",
      "CP01143",
      "CSIBM01143",
      "EBCDIC-FI-278+EURO",
      "EBCDIC-SE-278+EURO",
      "IBM01143",
      "IBM1143"
    ]

  @impl true
  def codec_id, do: :ebcdic1143

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1143, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1143, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1143, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1143, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1143, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1143, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1144 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1144"

  @impl true
  def aliases,
    do: [
      "CCSID01144",
      "CP01144",
      "CSPC8CODEPAGE1144",
      "EBCDIC-IT-280+EURO",
      "IBM01144",
      "IBM1144"
    ]

  @impl true
  def codec_id, do: :ebcdic1144

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1144, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1144, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1144, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1144, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1144, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1144, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1145 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1145"

  @impl true
  def aliases,
    do: ["CCSID01145", "CP01145", "CSIBM01145", "EBCDIC-ES-284+EURO", "IBM01145", "IBM1145"]

  @impl true
  def codec_id, do: :ebcdic1145

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1145, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1145, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1145, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1145, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1145, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1145, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1146 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1146"

  @impl true
  def aliases,
    do: [
      "CCSID01146",
      "CP01146",
      "CSPC8CODEPAGE1146",
      "EBCDIC-GB-285+EURO",
      "IBM01146",
      "IBM1146"
    ]

  @impl true
  def codec_id, do: :ebcdic1146

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1146, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1146, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1146, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1146, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1146, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1146, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1147 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1147"

  @impl true
  def aliases,
    do: ["CCSID01147", "CP01147", "CSIBM01147", "EBCDIC-FR-297+EURO", "IBM01147", "IBM1147"]

  @impl true
  def codec_id, do: :ebcdic1147

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1147, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1147, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1147, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1147, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1147, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1147, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1148 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1148"

  @impl true
  def aliases,
    do: [
      "CCSID01148",
      "CP01148",
      "CSIBM01148",
      "EBCDIC-INTERNATIONAL-500+EURO",
      "IBM01148",
      "IBM1148"
    ]

  @impl true
  def codec_id, do: :ebcdic1148

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1148, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1148, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1148, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1148, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1148, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1148, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1149 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1149"

  @impl true
  def aliases,
    do: ["CCSID01149", "CP01149", "CSIBM01149", "EBCDIC-IS-871+EURO", "IBM01149", "IBM1149"]

  @impl true
  def codec_id, do: :ebcdic1149

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1149, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1149, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1149, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1149, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1149, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1149, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1153 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1153"

  @impl true
  def aliases, do: ["CP1153", "IBM1153"]

  @impl true
  def codec_id, do: :ebcdic1153

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1153, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1153, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1153, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1153, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1153, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1153, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1154 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1154"

  @impl true
  def aliases, do: ["CP1154", "IBM1154"]

  @impl true
  def codec_id, do: :ebcdic1154

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1154, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1154, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1154, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1154, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1154, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1154, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1155 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1155"

  @impl true
  def aliases, do: ["CP1155", "IBM1155"]

  @impl true
  def codec_id, do: :ebcdic1155

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1155, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1155, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1155, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1155, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1155, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1155, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1156 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1156"

  @impl true
  def aliases, do: ["CP1156", "IBM1156"]

  @impl true
  def codec_id, do: :ebcdic1156

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1156, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1156, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1156, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1156, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1156, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1156, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1157 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1157"

  @impl true
  def aliases, do: ["CP1157", "IBM1157"]

  @impl true
  def codec_id, do: :ebcdic1157

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1157, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1157, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1157, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1157, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1157, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1157, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1158 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1158"

  @impl true
  def aliases, do: ["CP1158", "IBM1158"]

  @impl true
  def codec_id, do: :ebcdic1158

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1158, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1158, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1158, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1158, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1158, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1158, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1160 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1160"

  @impl true
  def aliases, do: ["CP1160", "IBM1160"]

  @impl true
  def codec_id, do: :ebcdic1160

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1160, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1160, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1160, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1160, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1160, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1160, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1164 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1164"

  @impl true
  def aliases, do: ["CP1164", "IBM1164"]

  @impl true
  def codec_id, do: :ebcdic1164

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1164, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1164, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1164, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1164, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1164, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1164, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1165 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1165"

  @impl true
  def aliases, do: ["IBM1165"]

  @impl true
  def codec_id, do: :ebcdic1165

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1165, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1165, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1165, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1165, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1165, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1165, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic1166 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-1166"

  @impl true
  def aliases, do: ["CP1166", "IBM1166"]

  @impl true
  def codec_id, do: :ebcdic1166

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic1166, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic1166, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic1166, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic1166, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic1166, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic1166, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic12712 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-12712"

  @impl true
  def aliases, do: ["CP12712", "IBM12712"]

  @impl true
  def codec_id, do: :ebcdic12712

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic12712, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic12712, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic12712, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic12712, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic12712, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic12712, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic16804 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-16804"

  @impl true
  def aliases, do: ["CP16804", "IBM16804"]

  @impl true
  def codec_id, do: :ebcdic16804

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic16804, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic16804, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic16804, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic16804, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic16804, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic16804, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic273 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-273"

  @impl true
  def aliases, do: ["CP273", "CSIBM273", "IBM273"]

  @impl true
  def codec_id, do: :ebcdic273

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic273, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic273, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic273, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic273, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic273, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic273, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic277 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-277"

  @impl true
  def aliases, do: ["CSIBM277", "EBCDIC-CP-DK", "EBCDIC-CP-NO", "IBM277"]

  @impl true
  def codec_id, do: :ebcdic277

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic277, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic277, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic277, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic277, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic277, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic277, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic278 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-278"

  @impl true
  def aliases, do: ["CP278", "CSIBM278", "EBCDIC-CP-FI", "EBCDIC-CP-SE", "IBM278"]

  @impl true
  def codec_id, do: :ebcdic278

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic278, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic278, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic278, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic278, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic278, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic278, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic280 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-280"

  @impl true
  def aliases, do: ["CP280", "CSIBM280", "EBCDIC-CP-IT", "IBM280"]

  @impl true
  def codec_id, do: :ebcdic280

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic280, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic280, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic280, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic280, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic280, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic280, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic282 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-282"

  @impl true
  def aliases, do: ["IBM282"]

  @impl true
  def codec_id, do: :ebcdic282

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic282, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic282, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic282, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic282, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic282, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic282, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic284 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-284"

  @impl true
  def aliases, do: ["CP284", "CSIBM284", "EBCDIC-CP-ES", "IBM284"]

  @impl true
  def codec_id, do: :ebcdic284

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic284, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic284, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic284, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic284, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic284, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic284, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic285 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-285"

  @impl true
  def aliases, do: ["CP285", "CSIBM285", "EBCDIC-CP-GB", "IBM285"]

  @impl true
  def codec_id, do: :ebcdic285

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic285, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic285, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic285, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic285, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic285, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic285, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic297 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-297"

  @impl true
  def aliases, do: ["CP297", "CSIBM297", "EBCDIC-CP-FR", "IBM297"]

  @impl true
  def codec_id, do: :ebcdic297

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic297, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic297, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic297, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic297, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic297, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic297, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic423 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-423"

  @impl true
  def aliases, do: ["CP423", "CSIBM423", "EBCDIC-CP-GR", "IBM423"]

  @impl true
  def codec_id, do: :ebcdic423

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic423, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic423, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic423, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic423, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic423, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic423, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic424 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-424"

  @impl true
  def aliases, do: ["CP424", "CSIBM424", "EBCDIC-CP-HE", "IBM424"]

  @impl true
  def codec_id, do: :ebcdic424

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic424, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic424, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic424, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic424, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic424, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic424, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic425 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-425"

  @impl true
  def aliases, do: ["IBM425"]

  @impl true
  def codec_id, do: :ebcdic425

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic425, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic425, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic425, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic425, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic425, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic425, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic4971 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-4971"

  @impl true
  def aliases, do: ["CP4971", "IBM4971"]

  @impl true
  def codec_id, do: :ebcdic4971

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic4971, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic4971, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic4971, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic4971, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic4971, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic4971, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic500 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-500"

  @impl true
  def aliases, do: ["CP500", "CSIBM500", "EBCDIC-CP-BE", "EBCDIC-CP-CH", "IBM500"]

  @impl true
  def codec_id, do: :ebcdic500

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic500, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic500, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic500, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic500, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic500, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic500, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic838 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-838"

  @impl true
  def aliases, do: ["CSIBMTHAI", "IBM-THAI", "IBM838"]

  @impl true
  def codec_id, do: :ebcdic838

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic838, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic838, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic838, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic838, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic838, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic838, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic870 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-870"

  @impl true
  def aliases, do: ["CP870", "CSIBM870", "EBCDIC-CP-ROECE", "EBCDIC-CP-YU", "IBM870"]

  @impl true
  def codec_id, do: :ebcdic870

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic870, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic870, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic870, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic870, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic870, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic870, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic871 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-871"

  @impl true
  def aliases, do: ["CP871", "CSIBM871", "EBCDIC-CP-IS", "IBM871"]

  @impl true
  def codec_id, do: :ebcdic871

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic871, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic871, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic871, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic871, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic871, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic871, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic875 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-875"

  @impl true
  def aliases, do: ["CP875", "EBCDIC-GREEK", "IBM875"]

  @impl true
  def codec_id, do: :ebcdic875

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic875, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic875, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic875, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic875, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic875, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic875, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic880 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-880"

  @impl true
  def aliases, do: ["CP880", "CSIBM880", "EBCDIC-CYRILLIC", "IBM880"]

  @impl true
  def codec_id, do: :ebcdic880

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic880, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic880, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic880, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic880, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic880, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic880, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic905 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-905"

  @impl true
  def aliases, do: ["CP905", "CSIBM905", "EBCDIC-CP-TR", "IBM905"]

  @impl true
  def codec_id, do: :ebcdic905

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic905, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic905, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic905, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic905, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic905, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic905, input)
end

defmodule Iconvex.Extras.Codecs.Ebcdic924 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "IBM-924"

  @impl true
  def aliases,
    do: ["CCSID00924", "CP00924", "CSIBM00924", "EBCDIC-LATIN9-EURO", "IBM00924", "IBM924"]

  @impl true
  def codec_id, do: :ebcdic924

  @impl true
  def decode(input), do: CodecSupport.decode(:ebcdic924, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:ebcdic924, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:ebcdic924, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:ebcdic924, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:ebcdic924, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:ebcdic924, input)
end

defmodule Iconvex.Extras.Codecs.Iso2022Jp3 do
  use Iconvex.Codec
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "ISO-2022-JP-3"

  @impl true
  def aliases, do: ["ISO-2022-JP-2004"]

  @impl true
  def codec_id, do: :iso2022_jp3

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: CodecSupport.decode_iso2022_jp3(input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard_iso2022_jp3(input)

  @impl true
  def decode_error_consumption(:incomplete_sequence, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  def decode_error_consumption(_kind, _sequence), do: 1

  @impl true
  def encode(codepoints), do: CodecSupport.encode_iso2022_jp3(codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard_iso2022_jp3(codepoints)

  @impl true
  def decode_to_ucs4_discard(input, endian),
    do: CodecSupport.decode_to_ucs4_discard(:iso2022_jp3, input, endian)

  @impl true
  def encode_from_ucs4_discard(input, endian),
    do: CodecSupport.encode_from_ucs4_discard(:iso2022_jp3, input, endian)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def stream_decoder_init, do: CodecSupport.stream_decoder_init_iso2022_jp3()

  @impl true
  def decode_chunk(input, state, final?),
    do: CodecSupport.decode_chunk_iso2022_jp3(input, state, final?)

  @impl true
  def stream_encoder_init, do: CodecSupport.stream_encoder_init_iso2022_jp3()

  @impl true
  def encode_chunk(codepoints, state, final?, policy),
    do: CodecSupport.encode_chunk_iso2022_jp3(codepoints, state, final?, policy)
end

defmodule Iconvex.Extras.Codecs.Riscos1 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "RISCOS-LATIN1"

  @impl true
  def aliases, do: []

  @impl true
  def codec_id, do: :riscos1

  @impl true
  def decode(input), do: CodecSupport.decode(:riscos1, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:riscos1, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:riscos1, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:riscos1, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:riscos1, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:riscos1, input)
end

defmodule Iconvex.Extras.Codecs.ShiftJisx0213 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "SHIFT_JISX0213"

  @impl true
  def aliases, do: ["SHIFT_JIS-2004"]

  @impl true
  def codec_id, do: :shift_jisx0213

  @impl true
  def decode(input), do: CodecSupport.decode(:shift_jisx0213, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:shift_jisx0213, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:shift_jisx0213, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:shift_jisx0213, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:shift_jisx0213, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:shift_jisx0213, input)
end

defmodule Iconvex.Extras.Codecs.Tds565 do
  use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
  alias Iconvex.Extras.CodecSupport

  @impl true
  def canonical_name, do: "TDS565"

  @impl true
  def aliases, do: ["ISO-IR-230"]

  @impl true
  def codec_id, do: :tds565

  @impl true
  def decode(input), do: CodecSupport.decode(:tds565, input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(:tds565, input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(:tds565, codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(:tds565, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(:tds565, input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(:tds565, input)
end
