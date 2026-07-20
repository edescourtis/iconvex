defmodule Iconvex.Specs.VendorMappingsTest do
  use ExUnit.Case, async: true

  alias Iconvex.Specs.VendorMappings

  @source_hashes %{
    "ARABIC.TXT" => "c66a997335e65f40aeee8fd63cd1d3b04b74ad50bf32fbf3e4d7214c9497d428",
    "CELTIC.TXT" => "cbc9da3acce632533cf4b8661b4ee3ab16dc510f782aca99bad8a4fa1a0cc99e",
    "CENTEURO.TXT" => "5f2e262a66a7d08317555835dcc8445f4666928f13f84a19951b19b42fe0b623",
    "CHINSIMP.TXT" => "0f60d32fc7b4f026ac365ccece18b3031c03be72131ef19ee51ae566851855e3",
    "CHINTRAD.TXT" => "7e541bfa1d7774bb33cb3de558102b65e1c4dcf76acbbfc263b2288f4d993569",
    "CROATIAN.TXT" => "cd3b6a79271664df7e4a935766906961bcfc6bf85cc8b9c877381a22044cf84e",
    "CYRILLIC.TXT" => "092ca7d0fe584b3fde176af4f2a175ceeba07b4c1a1c0b472c2016a6c92eafcc",
    "DEVANAGA.TXT" => "65ae8bfdfb279f95d075003256832927a78bd32825970f7098ee90cf503abe6a",
    "DINGBATS.TXT" => "bed8a47f01f770b3175790a35ad6cf9ee118832f6a31dfa86d2947e1a56043a5",
    "FARSI.TXT" => "ae9ed45404c3ecf617fbd4a910717eabe5b811a2b216c5503410c42be3616bce",
    "GAELIC.TXT" => "d4a4f0db7de96f2c66d929dafb55045eebdcfb77f426f4fd4b8a4ca560b33641",
    "GREEK.TXT" => "d57b3e0644a54f33396d53f3ca63a8483e96526de0d62be1dcd6eb40399a398e",
    "GUJARATI.TXT" => "ab820f324e5e12f6a612289401e4d4c178962c8f5e6930b93cd8de9737ab55b5",
    "GURMUKHI.TXT" => "da5a0002ef60c33054d9c52b934af29757f86bf2fac4669fe2e825c1b6aa2f69",
    "HEBREW.TXT" => "1d3e6c3ca5e0f242df9c22fd5d8ddc669f6b60015bac1c3b7cead487523bf9bf",
    "ICELAND.TXT" => "39b8d242bd0995a3b9f205273f098c1ff9bab4505a213c4e0313a700e47f26ce",
    "INUIT.TXT" => "c530d850057be2641415091543c1b0cbb504138fd1773a2fd6bf2a2538d45a58",
    "JAPANESE.TXT" => "a0443474f88dd56c8de52189b8c07c9098b77a396607afe46ed05ff1e8356af4",
    "KEYBOARD.TXT" => "b9b0aca8210c5fe24e2b58bac31d0ef121a4494e3c55cd2bf60e431d665a15dc",
    "KOREAN.TXT" => "23a9bbc95c5dc668a945a6ac07fd2697d353836312df35e3398e0af4c946ebcd",
    "ROMAN.TXT" => "18e571645be895e9553ed5c842ea8f65f9c5d3c9ccb43e66e0c33a132ed0d721",
    "ROMANIAN.TXT" => "a05436e00507e757e8badb5d582985b3c9d765b07609c2aeae9033dcfa02f43a",
    "SYMBOL.TXT" => "b8c529daba09a45872ec3b493e944680528206b829193594dcdd774a02d49d12",
    "THAI.TXT" => "ab10c28e8b2b3ee72ea67eed920d67ca8cb2ee86980294769633dc5d1cc9dbd5",
    "TURKISH.TXT" => "afce027def8db108de0607a76f1aae00787a4b2c7a44f68a359d9053c50a30bf",
    "stdenc.txt" => "4bcda13f60f43b79fa403240f3557dc3f8018e80495d61e2b089b2607a372a9d",
    "symbol.txt" => "deb78ca840a429311939b9d165890873f71fb23ef223ceeb144a6c6d641a7e52",
    "zdingbat.txt" => "2d8128a7280cdd47d93272f13c580d7f31fb34586ff65eaf29c7457c224974c0"
  }

  test "catalogues all Unicode Adobe and Apple codec maps and classifies non-codec files" do
    assert length(VendorMappings.encodings()) == 28

    assert Enum.frequencies_by(VendorMappings.encodings(), & &1.vendor) == %{
             "Adobe" => 3,
             "Apple" => 25
           }

    assert VendorMappings.exclusions() == [
             %{
               file: "CORPCHAR.TXT",
               reason: "Unicode corporate-zone constants without encoded byte mappings"
             },
             %{
               file: "UKRAINE.TXT",
               reason: "notes only; Mac Ukrainian was merged into the Cyrillic mapping"
             }
           ]

    assert Map.new(VendorMappings.sources(), &{&1.file, &1.sha256}) == @source_hashes
  end

  test "preserves Adobe decode precedence while accepting every Unicode alias" do
    assert VendorMappings.decode("ADOBE-STANDARD-ENCODING", <<0x27>>) == {:ok, [0x2019]}
    assert VendorMappings.encode("ADOBE-STANDARD-ENCODING", [0x2019]) == {:ok, <<0x27>>}

    assert VendorMappings.decode("ADOBE-STANDARD-ENCODING", <<0x20>>) == {:ok, [0x20]}
    assert VendorMappings.encode("ADOBE-STANDARD-ENCODING", [0x20]) == {:ok, <<0x20>>}
    assert VendorMappings.encode("ADOBE-STANDARD-ENCODING", [0xA0]) == {:ok, <<0x20>>}
  end

  test "implements Apple one-byte, multibyte, and multi-codepoint mappings" do
    assert VendorMappings.decode("MacCeltic", <<0xFF>>) == {:ok, [0x1E83]}
    assert VendorMappings.encode("MacCeltic", [0x1E83]) == {:ok, <<0xFF>>}

    assert VendorMappings.decode("MacDevanagari", <<0xE8, 0xE8>>) ==
             {:ok, [0x094D, 0x200C]}

    assert VendorMappings.encode("MacDevanagari", [0x094D, 0x200C]) ==
             {:ok, <<0xE8, 0xE8>>}

    assert VendorMappings.decode("MacDevanagari", <<0xE8, 0xE9>>) ==
             {:ok, [0x094D, 0x200D]}
  end

  test "implements documented Apple ASCII exceptions instead of blanket identity fill" do
    assert VendorMappings.decode("MacJapanese", <<0x5C>>) == {:ok, [0x00A5]}
    assert VendorMappings.decode("MacKeyboard", <<0x02>>) == {:ok, [0x21E5]}
    assert VendorMappings.decode("MacKeyboard", <<0x09>>) == {:ok, [0x2423]}
    assert VendorMappings.decode("MacRoman", <<?A>>) == {:ok, [?A]}
  end

  test "all MacKeyboard three/four-codepoint cells use the public UTF-8 fast path" do
    entry = Enum.find(VendorMappings.encodings(), &(&1.name == "MacKeyboard"))
    table = Iconvex.Tables.fetch!(%{id: entry.id, table_app: :iconvex_specs})

    compound =
      table.one
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.filter(fn
        {codepoints, _byte} when is_tuple(codepoints) -> tuple_size(codepoints) in 3..4
        {_codepoints, _byte} -> false
      end)

    assert length(compound) == 16

    for {codepoints, byte} <- compound do
      expected = codepoints |> Tuple.to_list() |> List.to_string()
      assert Iconvex.convert(<<byte>>, "MacKeyboard", "UTF-8") == {:ok, expected}
    end
  end

  test "reports incomplete multibyte prefixes and malformed source bytes precisely" do
    assert VendorMappings.decode("MacChineseSimp", <<0xA1>>) ==
             {:error, :incomplete_sequence, 0, <<0xA1>>}

    assert match?(
             {:error, :invalid_sequence, 0, _},
             VendorMappings.decode("ADOBE-STANDARD-ENCODING", <<0x00>>)
           )
  end

  test "every generated decoder and encoder entry is executable" do
    for entry <- VendorMappings.encodings() do
      table = Iconvex.Tables.fetch!(%{id: entry.id, table_app: :iconvex_specs})

      decode_mappings =
        Map.merge(
          table.many,
          table.one
          |> Tuple.to_list()
          |> Enum.with_index()
          |> Enum.reject(fn {value, _byte} -> is_nil(value) end)
          |> Map.new(fn {value, byte} -> {<<byte>>, value} end)
        )

      assert map_size(decode_mappings) == entry.decode_mappings
      assert map_size(table.encode) == entry.encode_mappings

      for {bytes, codepoints} <- decode_mappings do
        assert VendorMappings.decode(entry.name, bytes) == {:ok, Tuple.to_list(codepoints)},
               "#{entry.name} could not decode #{Base.encode16(bytes)}"

        assert {:ok, canonical_bytes} =
                 VendorMappings.encode(entry.name, Tuple.to_list(codepoints))

        assert VendorMappings.decode(entry.name, canonical_bytes) ==
                 {:ok, Tuple.to_list(codepoints)}
      end

      for {codepoints, bytes} <- table.encode do
        assert VendorMappings.encode(entry.name, Tuple.to_list(codepoints)) == {:ok, bytes}
      end
    end
  end

  test "registers collision-free vendor codecs through Iconvex's external codec API" do
    assert {:ok, "MacCeltic"} = Iconvex.canonical_name("MacCeltic")

    assert {:ok, "ADOBE-STANDARD-ENCODING"} =
             Iconvex.canonical_name("Adobe-Standard-Encoding")

    assert Iconvex.convert(<<0xFF>>, "MacCeltic", "UTF-8") == {:ok, <<0x1E83::utf8>>}
  end
end
