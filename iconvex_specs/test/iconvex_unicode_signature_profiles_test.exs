defmodule Iconvex.Specs.UnicodeSignatureProfilesTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.IconvexUTF16SignatureLEDefault, as: UTF16
  alias Iconvex.Specs.IconvexUTF32BESignature, as: UTF32BE
  alias Iconvex.Specs.IconvexUTF32LESignature, as: UTF32LE

  @vectors [0x0000, 0x0041, 0xFFFF, 0x10000, 0x10FFFF]

  test "UTF-16 profile signs nonempty output and supports either input signature" do
    assert UTF16.encode([]) == {:ok, <<>>}

    assert UTF16.encode([?A, 0x1F600]) ==
             {:ok, <<0xFEFF::16-little, 0x41::16-little, 0xD83D::16-little, 0xDE00::16-little>>}

    assert UTF16.decode(<<0xFEFF::16-little, 0x41::16-little>>) == {:ok, [?A]}
    assert UTF16.decode(<<0xFEFF::16-big, 0x41::16-big>>) == {:ok, [?A]}
    assert UTF16.decode(<<0x41::16-little>>) == {:ok, [?A]}
  end

  test "UTF-16 profile validates scalars and reports offsets after a signature" do
    assert UTF16.decode(<<0xD83D::16-little, 0xDE00::16-little>>) == {:ok, [0x1F600]}
    assert match?({:error, :incomplete_sequence, 0, _}, UTF16.decode(<<0x3D, 0xD8>>))
    assert match?({:error, :invalid_sequence, 0, _}, UTF16.decode(<<0x00, 0xDC>>))

    assert {:error, :invalid_sequence, 2, <<0x00, 0xDC>>} =
             UTF16.decode(<<0xFEFF::16-little, 0xDC00::16-little>>)

    assert UTF16.encode([0xD800]) == {:error, :unrepresentable_character, 0xD800}
  end

  test "UTF-32 profiles sign nonempty output in their fixed endian" do
    assert UTF32BE.encode([]) == {:ok, <<>>}
    assert UTF32LE.encode([]) == {:ok, <<>>}

    assert UTF32BE.encode(@vectors) ==
             {:ok,
              <<0x0000FEFF::32-big, 0x0000::32-big, 0x0041::32-big, 0xFFFF::32-big,
                0x10000::32-big, 0x10FFFF::32-big>>}

    assert UTF32LE.encode(@vectors) ==
             {:ok,
              <<0x0000FEFF::32-little, 0x0000::32-little, 0x0041::32-little, 0xFFFF::32-little,
                0x10000::32-little, 0x10FFFF::32-little>>}
  end

  test "UTF-32 profiles consume only a matching signature" do
    assert UTF32BE.decode(<<0x0000FEFF::32-big, 0x41::32-big>>) == {:ok, [?A]}
    assert UTF32BE.decode(<<0x41::32-big>>) == {:ok, [?A]}
    assert UTF32LE.decode(<<0x0000FEFF::32-little, 0x41::32-little>>) == {:ok, [?A]}
    assert UTF32LE.decode(<<0x41::32-little>>) == {:ok, [?A]}

    assert match?({:error, :invalid_sequence, 0, _}, UTF32BE.decode(<<0x0000FEFF::32-little>>))
    assert match?({:error, :invalid_sequence, 0, _}, UTF32LE.decode(<<0x0000FEFF::32-big>>))
  end

  test "UTF-32 profiles validate scalars and report offsets after a signature" do
    assert UTF32BE.decode(<<0, 0, 0>>) == {:error, :incomplete_sequence, 0, <<0, 0, 0>>}
    assert match?({:error, :invalid_sequence, 0, _}, UTF32BE.decode(<<0xD800::32-big>>))
    assert match?({:error, :invalid_sequence, 0, _}, UTF32LE.decode(<<0x110000::32-little>>))

    assert {:error, :invalid_sequence, 4, <<0xD800::32-big>>} =
             UTF32BE.decode(<<0x0000FEFF::32-big, 0xD800::32-big>>)

    assert UTF32BE.encode([0xD800]) == {:error, :unrepresentable_character, 0xD800}
  end

  test "only neutral Iconvex identities are registered" do
    for {name, alias_name} <- [
          {"ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT", "ICONVEX_UTF_16_SIGNATURE_LE_DEFAULT"},
          {"ICONVEX-UTF-32BE-SIGNATURE", "ICONVEX_UTF_32BE_SIGNATURE"},
          {"ICONVEX-UTF-32LE-SIGNATURE", "ICONVEX_UTF_32LE_SIGNATURE"}
        ] do
      assert {:ok, %{canonical: ^name}} = Iconvex.Registry.resolve(name)
      assert {:ok, %{canonical: ^name}} = Iconvex.Registry.resolve(alias_name)
    end

    for old_name <- [
          "x-UTF-16LE-BOM",
          "UTF-16LE-BOM",
          "UTF_16LE_BOM",
          "X-UTF-32BE-BOM",
          "UTF-32BE-BOM",
          "UTF_32BE_BOM",
          "X-UTF-32LE-BOM",
          "UTF-32LE-BOM",
          "UTF_32LE_BOM"
        ] do
      assert :error = Iconvex.Registry.resolve(old_name)
    end
  end

  test "discard and substitution preserve the profile framing policy" do
    assert UTF16.encode_discard([0xD800]) == {:ok, <<>>}
    assert UTF32BE.encode_discard([0xD800, ?A]) == {:ok, <<0x0000FEFF::32-big, ?A::32-big>>}

    assert UTF32LE.encode_substitute([0xD800], fn 0xD800 -> [?A] end) ==
             {:ok, <<0x0000FEFF::32-little, ?A::32-little>>}

    assert UTF16.decode_discard(<<0xFEFF::16-little, 0xDC00::16-little, ?A::16-little>>) ==
             {:ok, [?A]}
  end

  test "fixed-width recovery consumption does not lose framing" do
    assert UTF16.decode_error_consumption(:invalid_sequence, <<0, 0>>) == 2
    assert UTF32BE.decode_error_consumption(:invalid_sequence, <<0, 0, 0, 0>>) == 4
    assert UTF32LE.decode_error_consumption(:incomplete_sequence, <<0, 0>>) == 1
  end
end
