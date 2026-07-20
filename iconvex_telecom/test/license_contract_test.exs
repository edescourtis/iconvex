defmodule Iconvex.Telecom.LicenseContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)
  @libiconv_lgpl_sha256 "20e50fe7aae3e56378ebf0417d9de904f55a0e61e4df315333e632a4d3555d95"

  test "original library code uses GNU libiconv's LGPL-2.1-or-later license" do
    license = File.read!(Path.join(@root, "LICENSE"))
    mix = File.read!(Path.join(@root, "mix.exs"))

    assert sha256(license) == @libiconv_lgpl_sha256
    assert mix =~ ~s(licenses: ["LGPL-2.1-or-later")
    assert File.regular?(Path.join(@root, "LICENSE.APACHE-2.0"))
    assert File.regular?(Path.join(@root, "LICENSE.UNICODE"))
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
