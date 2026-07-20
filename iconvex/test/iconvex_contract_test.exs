defmodule Iconvex.ContractTest do
  use ExUnit.Case, async: false

  test "exposes GNU libiconv 1.19 default codec set" do
    encodings = Iconvex.encodings()

    assert length(encodings) == 112
    assert "UTF-8" in encodings
    assert "CP1252" in encodings
    assert "GB18030:2022" in encodings
    refute "ISO-2022-JP-3" in encodings
    refute "IBM-16804" in encodings
  end

  test "resolves aliases case-insensitively" do
    assert Iconvex.canonical_name("windows-1252") == {:ok, "CP1252"}
    assert Iconvex.canonical_name("csisolatin1") == {:ok, "ISO-8859-1"}
    assert Iconvex.canonical_name("not-an-encoding") == :error
  end

  test "specification profile and registration aliases resolve to their byte codec" do
    assert Iconvex.canonical_name("ISO-8859-6-E") == {:ok, "ISO-8859-6"}
    assert Iconvex.canonical_name("ISO-8859-6-I") == {:ok, "ISO-8859-6"}
    assert Iconvex.canonical_name("ISO-8859-8-E") == {:ok, "ISO-8859-8"}
    assert Iconvex.canonical_name("ISO-8859-8-I") == {:ok, "ISO-8859-8"}
    assert Iconvex.canonical_name("ISO-IR-168") == {:ok, "JIS_X0208"}
    # ISO-IR-180 is TCVN 5712 profile VN2 (VSCII-2), not RFC 1456 VISCII.
    # Core deliberately leaves it unclaimed so the exact Specs provider can
    # own it without a false byte-identity or registration collision.
    assert Iconvex.canonical_name("ISO-IR-180") == :error
    assert Iconvex.canonical_name("ISO-IR-227") == {:ok, "ISO-8859-7"}
    assert Iconvex.canonical_name("unicodeFFFE") == {:ok, "UTF-16BE"}
    assert Iconvex.canonical_name("CP1201") == {:ok, "UTF-16BE"}
    assert Iconvex.canonical_name("IBM-5054") == {:ok, "ISO-2022-JP-1"}
    assert Iconvex.canonical_name("JIS_Encoding") == {:ok, "ISO-2022-JP-1"}
    assert Iconvex.canonical_name("csJISEncoding") == {:ok, "ISO-2022-JP-1"}

    for name <- ["ISO-IR-162", "ISO-IR-174", "ISO-IR-176"] do
      assert Iconvex.canonical_name(name) == {:ok, "UCS-2BE"}
    end

    for name <- ["ISO-IR-163", "ISO-IR-175", "ISO-IR-177"] do
      assert Iconvex.canonical_name(name) == {:ok, "UCS-4BE"}
    end

    for name <- ["ISO-IR-190", "ISO-IR-191", "ISO-IR-192", "ISO-IR-196"] do
      assert Iconvex.canonical_name(name) == {:ok, "UTF-8"}
    end

    for name <- ["ISO-IR-193", "ISO-IR-194", "ISO-IR-195"] do
      assert Iconvex.canonical_name(name) == {:ok, "UTF-16"}
    end
  end

  test "converts a CP1252 binary to UTF-8" do
    assert Iconvex.convert(<<0x63, 0x61, 0x66, 0xE9>>, "CP1252", "UTF-8") ==
             {:ok, "café"}
  end

  test "unknown encoding names never create atoms" do
    Iconvex.canonical_name("warm-up-unknown")
    before = :erlang.system_info(:atom_count)

    for index <- 1..100 do
      assert Iconvex.canonical_name("USER-SUPPLIED-UNKNOWN-#{index}") == :error
    end

    assert :erlang.system_info(:atom_count) == before
  end
end
