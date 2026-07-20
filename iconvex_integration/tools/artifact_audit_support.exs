defmodule IconvexIntegration.ArtifactAuditSupport do
  @moduledoc false

  def ensure_crypto! do
    unless Code.ensure_loaded?(:crypto) do
      root = :code.root_dir() |> List.to_string()

      crypto_ebin =
        [root, "lib", "crypto-*", "ebin"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.sort()
        |> List.last()

      unless is_binary(crypto_ebin) do
        raise "could not locate the OTP :crypto ebin directory below #{root}"
      end

      unless :code.add_patha(String.to_charlist(crypto_ebin)) == true do
        raise "could not add the OTP :crypto ebin directory to the clean-consumer code path"
      end

      unless Code.ensure_loaded?(:crypto) do
        raise "could not load :crypto from the OTP installation"
      end
    end

    case Application.ensure_all_started(:crypto) do
      {:ok, _started} -> :ok
      {:error, reason} -> raise "could not start :crypto: #{inspect(reason)}"
    end
  end

  def regular_files!(root) when is_binary(root), do: walk!(root, "")

  def tree_sha256!(root, relative_files)
      when is_binary(root) and is_list(relative_files) do
    material =
      Enum.map(relative_files, fn relative ->
        content = root |> Path.join(relative) |> File.read!()

        [
          <<byte_size(relative)::unsigned-big-64>>,
          relative,
          <<byte_size(content)::unsigned-big-64>>,
          content
        ]
      end)

    apply(:crypto, :hash, [:sha256, material]) |> Base.encode16(case: :lower)
  end

  def hex_tar!(path) when is_binary(path) do
    unless File.regular?(path), do: raise("Hex tarball is absent: #{path}")
    tar_binary = File.read!(path)

    entries =
      case :erl_tar.extract({:binary, tar_binary}, [:memory]) do
        {:ok, entries} ->
          Enum.map(entries, fn {name, contents} -> {List.to_string(name), contents} end)

        {:error, reason} ->
          raise "could not read Hex tarball #{path}: #{inspect(reason)}"
      end

    expected_names = ["CHECKSUM", "VERSION", "contents.tar.gz", "metadata.config"]
    actual_names = Enum.map(entries, &elem(&1, 0)) |> Enum.sort()

    unless actual_names == expected_names do
      raise "Hex outer file set differs for #{path}: #{inspect(actual_names)}"
    end

    files = Map.new(entries)
    version = Map.fetch!(files, "VERSION")
    checksum = Map.fetch!(files, "CHECKSUM")
    metadata_binary = Map.fetch!(files, "metadata.config")
    contents = Map.fetch!(files, "contents.tar.gz")

    unless version == "3",
      do: raise("unsupported Hex tar version in #{path}: #{inspect(version)}")

    actual_checksum =
      :crypto.hash(:sha256, [version, metadata_binary, contents])
      |> Base.encode16(case: :upper)

    unless checksum == actual_checksum do
      raise "Hex inner checksum differs for #{path}: #{checksum} != #{actual_checksum}"
    end

    ensure_hex_tar_reader!()

    case apply(:mix_hex_tarball, :unpack, [tar_binary, :memory]) do
      {:ok, %{metadata: metadata, contents: contents}} ->
        normalized_contents =
          Enum.map(contents, fn {name, content} ->
            name = if is_binary(name), do: name, else: List.to_string(name)
            {name, content}
          end)

        content_map = Map.new(normalized_contents)

        unless map_size(content_map) == length(normalized_contents) do
          raise "duplicate file in Hex contents tar: #{path}"
        end

        %{metadata: metadata, contents: content_map}

      {:error, reason} ->
        raise "official Hex reader rejected #{path}: #{inspect(reason)}"

      other ->
        raise "official Hex reader returned an invalid result for #{path}: #{inspect(other)}"
    end
  end

  def verify_contents_root!(contents, root, label)
      when is_map(contents) and is_binary(root) do
    artifact_files = regular_files!(root) |> Enum.sort()
    tar_files = contents |> Map.keys() |> Enum.sort()

    unless tar_files == artifact_files do
      raise "Hex tar contents differ from unpacked artifact for #{label}: " <>
              "#{inspect(tar_files)} != #{inspect(artifact_files)}"
    end

    for relative <- artifact_files do
      unless Map.fetch!(contents, relative) == File.read!(Path.join(root, relative)) do
        raise "Hex tar content differs from unpacked artifact: #{label}/#{relative}"
      end
    end

    :ok
  end

  defp walk!(root, relative) do
    directory = if relative == "", do: root, else: Path.join(root, relative)

    directory
    |> File.ls!()
    |> Enum.sort()
    |> Enum.flat_map(fn name ->
      child_relative = if relative == "", do: name, else: Path.join(relative, name)
      child = Path.join(root, child_relative)

      case File.lstat!(child).type do
        :directory -> walk!(root, child_relative)
        :regular -> [child_relative]
        type -> raise "artifact tree contains unsupported #{type}: #{child}"
      end
    end)
  end

  defp ensure_hex_tar_reader! do
    unless Code.ensure_loaded?(:mix_hex_tarball) do
      :ok = Mix.Local.append_archives()
    end

    unless Code.ensure_loaded?(:mix_hex_tarball) do
      raise "could not load Hex's checksum-validating tar reader from Mix archives"
    end
  end
end
