defmodule IconvexIntegration.HexPublishScriptContractTest do
  use ExUnit.Case, async: true

  @workspace Path.expand("../..", __DIR__)
  @script Path.join(@workspace, "iconvex_integration/tools/publish_hex.sh")
  @version "0.1.0"
  @packages [
    "iconvex",
    "iconvex_specs_icu_archive_a",
    "iconvex_specs_icu_archive_b",
    "iconvex_specs_icu_archive_c",
    "iconvex_extras",
    "iconvex_telecom",
    "iconvex_specs"
  ]

  test "publisher has a strict, secret-safe, dry-run default contract" do
    script = File.read!(@script)

    assert script =~ "set -Eeuo pipefail"
    refute script =~ "set -x"
    refute script =~ "/Users/"
    refute script =~ "/private/tmp"
    assert script =~ ~S(DEFAULT_ASDF_DATA_DIR="${ASDF_DATA_DIR:-${HOME}/.asdf}")
    assert script =~ ~S(${TMPDIR:-/tmp}/iconvex-hex-preflight.XXXXXX)
    assert script =~ "EXPECTED_HEX_USER=\"eric.descourtis\""
    assert script =~ "EXPECTED_GITHUB_REPOSITORY=\"edescourtis/iconvex\""
    assert script =~ "EXPECTED_VERSION=\"0.1.0\""
    assert script =~ "EXPECTED_HEX_VERSION=\"2.2.1\""

    assert script =~
             "EXPECTED_MANIFEST_SHA256=\"1411f0bde757a4bd2c242814bcdfa23829d36ad40e6e9bb6b80d01ff1339e528\""

    assert script =~ "export HEX_API_URL=\"https://hex.pm/api\""
    assert script =~ "export HEX_UNSAFE_HTTPS=\"0\""
    assert script =~ "export HEX_UNSAFE_REGISTRY=\"0\""
    assert script =~ "export HEX_NO_VERIFY_REPO_ORIGIN=\"0\""
    assert script =~ "HEX_API_URL}/packages/"
    assert script =~ "ICONVEX_PUBLISH_CURL_BIN"
    assert script =~ "remote release checksum mismatch"
    assert script =~ "remote release publisher mismatch"
    assert script =~ "remote package ownership collision"
    assert script =~ "candidate_tar_sha256"
    assert script =~ "complete outer package"
    assert script =~ "ICONVEX_SOURCE_URL="

    assert script =~
             ~S(DEFAULT_RELEASE_ROOT="${DEFAULT_WORKSPACE}/iconvex_release_0.1.0")

    assert script =~ "mix hex.publish package --dry-run --yes"
    assert script =~ "mix hex.publish package --yes"
  end

  test "default mode preflights every package in dependency order and never publishes" do
    fixture = fixture!()

    {output, 0} = run_script(fixture)

    assert output =~ "DRY RUN COMPLETE: no package published"
    assert actions(fixture.log, "FREEZE") == @packages
    assert actions(fixture.log, "BUILD") == @packages
    assert actions(fixture.log, "DRY_RUN") == @packages
    assert actions(fixture.log, "PUBLISH") == []
    assert actions(fixture.log, "API_PACKAGE") == @packages
    assert actions(fixture.log, "API_RELEASE") == @packages

    assert Enum.all?(contexts(fixture.log, "DRY_RUN"), fn path ->
             not String.starts_with?(path, fixture.workspace <> "/")
           end)
  end

  test "live mode publishes in dependency order, interleaving dry-run and publish" do
    fixture = fixture!()

    {output, 0} =
      run_script(fixture, ["--publish"], [
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert output =~ "PUBLISH COMPLETE: 7 packages"
    assert actions(fixture.log, "PUBLISH") == @packages
    assert actions(fixture.log, "DRY_RUN") == @packages
    assert actions(fixture.log, "BUILD") == @packages ++ @packages

    assert actions(fixture.log, "API_PACKAGE") == @packages ++ @packages
    assert actions(fixture.log, "API_RELEASE") == @packages ++ @packages

    lines = File.read!(fixture.log) |> String.split("\n", trim: true)

    # The up-front source-artifact verification builds every package first; the
    # live phase then interleaves reverify-build, dry-run, and publish for each
    # package in dependency order, so each dependent is dry-run and published
    # only after its ancestors are live.
    interleaved =
      lines
      |> Enum.filter(
        &(String.starts_with?(&1, "BUILD ") or String.starts_with?(&1, "DRY_RUN ") or
            String.starts_with?(&1, "PUBLISH "))
      )
      |> Enum.drop(length(@packages))

    assert interleaved ==
             Enum.flat_map(@packages, fn package ->
               ["BUILD #{package}", "DRY_RUN #{package}", "PUBLISH #{package}"]
             end)

    # Every remote preflight query still completes before any package is
    # published, so ownership and same-version collisions abort with zero
    # mutation.
    first_publish = Enum.find_index(lines, &String.starts_with?(&1, "PUBLISH "))

    assert lines
           |> Enum.take(first_publish)
           |> Enum.filter(
             &(String.starts_with?(&1, "API_PACKAGE ") or String.starts_with?(&1, "API_RELEASE "))
           ) ==
             Enum.flat_map(@packages, fn package ->
               ["API_PACKAGE #{package}", "API_RELEASE #{package}"]
             end)
  end

  test "package ownership collision is found during the complete remote preflight" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_COLLISION_PACKAGE", "iconvex_extras"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "remote package ownership collision: iconvex_extras"
    assert actions(fixture.log, "API_PACKAGE") == @packages
    assert actions(fixture.log, "API_RELEASE") == @packages
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "same-version checksum mismatch is found before any package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_CHECKSUM_MISMATCH_PACKAGE", "iconvex_specs_icu_archive_c"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "remote release checksum mismatch: iconvex_specs_icu_archive_c 0.1.0"
    assert actions(fixture.log, "API_PACKAGE") == @packages
    assert actions(fixture.log, "API_RELEASE") == @packages
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "same-version publisher mismatch is found before any package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_PUBLISHER_MISMATCH_PACKAGE", "iconvex_specs_icu_archive_b"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "remote release publisher mismatch: iconvex_specs_icu_archive_b 0.1.0"
    assert actions(fixture.log, "API_PACKAGE") == @packages
    assert actions(fixture.log, "API_RELEASE") == @packages
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "exact owner publisher and checksum make an existing release resumable" do
    fixture = fixture!()

    {output, 0} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_EXACT_RELEASES", Enum.join(@packages, " ")},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert output =~ "already published and verified; skipping: iconvex 0.1.0"
    assert output =~ "published=0 skipped=7"
    assert actions(fixture.log, "API_PACKAGE") == @packages
    assert actions(fixture.log, "API_RELEASE") == @packages
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "a later remote API failure is collected before validation and causes zero mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_API_FAIL_PACKAGE", "iconvex_telecom"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "Hex API package query failed for iconvex_telecom: HTTP 503"
    assert actions(fixture.log, "API_PACKAGE") == @packages
    assert actions(fixture.log, "API_RELEASE") == @packages
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "post-publish readback rejects a publisher mismatch immediately" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_POST_PUBLISH_BAD_PUBLISHER_PACKAGE", "iconvex"},
        {"ICONVEX_HEX_VERIFY_ATTEMPTS", "1"},
        {"ICONVEX_HEX_VERIFY_DELAY_SECONDS", "0"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "post-publish verification failed for iconvex"
    assert output =~ "remote release publisher mismatch: iconvex 0.1.0"
    assert actions(fixture.log, "PUBLISH") == ["iconvex"]
  end

  test "live mode keeps using frozen trees after original sources mutate" do
    fixture = fixture!()

    {output, 0} =
      run_script(fixture, ["--publish"], [
        {"FAKE_MUTATE_ORIGINAL_ON_FIRST_DRY_RUN", "1"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert output =~ "PUBLISH COMPLETE: 7 packages"
    assert File.read!(Path.join(fixture.workspace, "iconvex/mix.exs")) =~ "MUTATED ORIGINAL"
    assert actions(fixture.log, "PUBLISH") == @packages

    assert Enum.all?(contexts(fixture.log, "PUBLISH"), fn path ->
             not String.starts_with?(path, fixture.workspace <> "/")
           end)
  end

  test "frozen source build mismatch causes zero publishes" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_BUILD_MISMATCH_PACKAGE", "iconvex_extras"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "source build differs from final candidate: iconvex_extras-0.1.0.tar"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "an Nth dry-run failure aborts before publishing that package or any later one" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_DRY_RUN_FAIL_AT", "4"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "injected dry-run failure 4"
    # Interleaved release: each package is dry-run immediately before it is
    # published, so a failure at package four stops the release with the first
    # three already published and no later package touched.
    assert actions(fixture.log, "DRY_RUN") == Enum.take(@packages, 4)
    assert actions(fixture.log, "PUBLISH") == Enum.take(@packages, 3)
  end

  test "unexpected Hex archive version causes zero package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_VERSION", "2.2.0"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "Hex version mismatch; expected 2.2.1"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "wrong authenticated Hex user blocks all package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_HEX_USER", "somebody.else"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "authenticated Hex user mismatch"
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "candidate checksum mismatch blocks all package mutation" do
    fixture = fixture!()
    File.write!(Path.join(fixture.release_root, "tarballs/iconvex-0.1.0.tar"), "tampered")

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "candidate SHA-256 mismatch"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "conflicting GitHub package metadata blocks all package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_GITHUB_URL", "https://github.com/not-edescourtis/not-iconvex"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "GitHub package link missing or mismatched"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "missing GitHub source URL blocks all package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_OMIT_SOURCE_URL", "1"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "Mix source_url mismatch for iconvex"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "missing GitHub package link blocks all package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_OMIT_GITHUB_LINK", "1"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "GitHub package link missing or mismatched for iconvex"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "conflicting GitHub source URL blocks all package mutation" do
    fixture = fixture!()

    {output, status} =
      run_script(fixture, ["--publish"], [
        {"FAKE_SOURCE_URL", "https://github.com/not-edescourtis/not-iconvex"},
        {"ICONVEX_HEX_PUBLISH_CONFIRM", "publish Iconvex 0.1.0 as eric.descourtis"}
      ])

    assert status != 0
    assert output =~ "Mix source_url mismatch for iconvex"
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  test "live mode without exact typed or environment confirmation performs no publish" do
    fixture = fixture!()

    {output, status} = run_script(fixture, ["--publish"])

    assert status != 0
    assert output =~ "live publish confirmation required"
    # The confirmation gate is checked before any per-package dry-run or publish,
    # so a missing confirmation mutates nothing and dry-runs nothing.
    assert actions(fixture.log, "DRY_RUN") == []
    assert actions(fixture.log, "PUBLISH") == []
  end

  defp fixture! do
    root =
      Path.join(System.tmp_dir!(), "iconvex-hex-publish-#{System.unique_integer([:positive])}")

    workspace = Path.join(root, "workspace")
    release_root = Path.join(root, "release")
    bin = Path.join(root, "bin")
    erlang_bin = Path.join(root, "erlang-bin")
    log = Path.join(root, "calls.log")

    File.mkdir_p!(Path.join(release_root, "tarballs"))
    File.mkdir_p!(Path.join(release_root, "manifests"))
    File.mkdir_p!(bin)
    File.mkdir_p!(erlang_bin)

    sums =
      Enum.map_join(@packages, "", fn package ->
        filename = "#{package}-#{@version}.tar"
        contents = "candidate #{package}\n"
        File.write!(Path.join(release_root, "tarballs/#{filename}"), contents)
        "#{sha256(contents)}  #{filename}\n"
      end)

    File.write!(Path.join(release_root, "manifests/SHA256SUMS"), sums)

    script = Path.join(root, "publish_hex.sh")

    test_script =
      @script
      |> File.read!()
      |> String.replace(
        ~r/EXPECTED_MANIFEST_SHA256="[0-9a-f]{64}"/,
        "EXPECTED_MANIFEST_SHA256=\"#{sha256(sums)}\""
      )

    File.write!(script, test_script)
    File.chmod!(script, 0o755)

    Enum.each(@packages, fn package ->
      package_root = Path.join(workspace, package)
      File.mkdir_p!(package_root)
      File.write!(Path.join(package_root, "mix.exs"), "# fixture\n")
    end)

    fake_elixir = Path.join(bin, "elixir")
    fake_mix = Path.join(bin, "mix")
    fake_curl = Path.join(bin, "curl")

    File.write!(fake_elixir, """
    #!/usr/bin/env bash
    printf 'Erlang/OTP 28 [erts-16.2]\nElixir 1.19.5 (compiled with Erlang/OTP 28)\n'
    """)

    File.write!(fake_mix, """
    #!/usr/bin/env bash
    set -eu
    package="$(basename "$PWD")"

    [[ "${HEX_API_URL:-}" == "https://hex.pm/api" ]] || exit 92
    [[ "${HEX_UNSAFE_HTTPS:-}" == "0" ]] || exit 93
    [[ "${HEX_UNSAFE_REGISTRY:-}" == "0" ]] || exit 94
    [[ "${HEX_NO_VERIFY_REPO_ORIGIN:-}" == "0" ]] || exit 95

    if [[ "$*" == "hex --version" ]]; then
      printf 'Hex v%s\n' "${FAKE_HEX_VERSION:-2.2.1}"
      exit 0
    fi

    if [[ "$*" == "deps.get" ]]; then
      exit 0
    fi

    if [[ "$*" == hex.build* && "$*" == *"--unpack"* ]]; then
      output=""
      previous=""
      for argument in "$@"; do
        if [[ "$previous" == "--output" ]]; then output="$argument"; fi
        previous="$argument"
      done
      printf 'FREEZE %s\n' "$package" >> "$FAKE_MIX_LOG"
      mkdir -p "$output"
      cp mix.exs "$output/mix.exs"
      exit 0
    fi

    if [[ "$*" == *"Mix.Project.config"* ]]; then
      printf 'ICONVEX_APP=%s\n' "$package"
      printf 'ICONVEX_VERSION=0.1.0\n'
      if [[ "${FAKE_OMIT_SOURCE_URL:-}" != "1" ]]; then
        printf 'ICONVEX_SOURCE_URL=%s\n' "${FAKE_SOURCE_URL:-https://github.com/edescourtis/iconvex}"
      fi
      if [[ "${FAKE_OMIT_GITHUB_LINK:-}" != "1" ]]; then
        printf 'ICONVEX_GITHUB_URL=%s\n' "${FAKE_GITHUB_URL:-https://github.com/edescourtis/iconvex}"
      fi
      exit 0
    fi

    if [[ "$*" == "hex.user whoami" ]]; then
      printf 'Username: %s\n' "${FAKE_HEX_USER:-eric.descourtis}"
      exit 0
    fi

    if [[ "$*" == hex.build* ]]; then
      output=""
      previous=""
      for argument in "$@"; do
        if [[ "$previous" == "--output" ]]; then output="$argument"; fi
        previous="$argument"
      done
      printf 'BUILD %s\n' "$package" >> "$FAKE_MIX_LOG"
      printf 'CONTEXT BUILD %s\n' "$PWD" >> "$FAKE_MIX_LOG"
      if [[ "${FAKE_BUILD_MISMATCH_PACKAGE:-}" == "$package" ]]; then
        printf 'mismatched build\n' > "$output"
      else
        cp "$ICONVEX_RELEASE_ROOT/tarballs/$package-0.1.0.tar" "$output"
      fi
      exit 0
    fi

    if [[ "$*" == "hex.publish package --dry-run --yes" ]]; then
      printf 'DRY_RUN %s\n' "$package" >> "$FAKE_MIX_LOG"
      printf 'CONTEXT DRY_RUN %s\n' "$PWD" >> "$FAKE_MIX_LOG"
      if [[ "${FAKE_MUTATE_ORIGINAL_ON_FIRST_DRY_RUN:-}" == "1" && "$package" == "iconvex" ]]; then
        printf '# MUTATED ORIGINAL\n' > "$FAKE_ORIGINAL_WORKSPACE/iconvex/mix.exs"
      fi
      dry_run_count="$(awk '$1 == "DRY_RUN" { count++ } END { print count + 0 }' "$FAKE_MIX_LOG")"
      if [[ -n "${FAKE_DRY_RUN_FAIL_AT:-}" && "$dry_run_count" == "$FAKE_DRY_RUN_FAIL_AT" ]]; then
        printf 'injected dry-run failure %s\n' "$dry_run_count" >&2
        exit 96
      fi
      exit 0
    fi

    if [[ "$*" == "hex.publish package --yes" ]]; then
      if grep -q 'MUTATED ORIGINAL' mix.exs; then
        printf 'publish used mutable original source\n' >&2
        exit 97
      fi
      printf 'PUBLISH %s\n' "$package" >> "$FAKE_MIX_LOG"
      printf 'CONTEXT PUBLISH %s\n' "$PWD" >> "$FAKE_MIX_LOG"
      exit 0
    fi

    printf 'unexpected fake mix invocation: %s\n' "$*" >&2
    exit 91
    """)

    File.write!(fake_curl, """
    #!/usr/bin/env bash
    set -eu

    output=""
    url=""
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --output|--write-out|--header|--connect-timeout|--max-time|--retry)
          if [[ "$1" == "--output" ]]; then output="$2"; fi
          shift 2
          ;;
        --*)
          shift
          ;;
        *)
          url="$1"
          shift
          ;;
      esac
    done

    prefix="https://hex.pm/api/packages/"
    case "$url" in
      "$prefix"*) ;;
      *) printf 'unexpected API URL: %s\n' "$url" >&2; exit 88 ;;
    esac

    path="${url#"$prefix"}"
    case "$path" in
      */releases/0.1.0)
        package="${path%%/releases/*}"
        kind="RELEASE"
        ;;
      *)
        package="$path"
        kind="PACKAGE"
        ;;
    esac

    printf 'API_%s %s\n' "$kind" "$package" >> "$FAKE_MIX_LOG"
    published=false
    if awk -v package="$package" '$1 == "PUBLISH" && $2 == package { found = 1 } END { exit !found }' "$FAKE_MIX_LOG"; then
      published=true
    fi

    exact=false
    case " ${FAKE_HEX_EXACT_RELEASES:-} " in
      *" $package "*) exact=true ;;
    esac

    status=404
    body='{}'
    checksum="$(awk -v filename="$package-0.1.0.tar" '$2 == filename { print $1 }' "$ICONVEX_RELEASE_ROOT/manifests/SHA256SUMS")"

    if [[ "$kind" == "PACKAGE" ]]; then
      if [[ "${FAKE_HEX_API_FAIL_PACKAGE:-}" == "$package" ]]; then
        status=503
        body='{"error":"injected failure"}'
      elif [[ "${FAKE_HEX_COLLISION_PACKAGE:-}" == "$package" ]]; then
        status=200
        body="{\\\"name\\\":\\\"$package\\\",\\\"owners\\\":[{\\\"username\\\":\\\"somebody.else\\\"}]}"
      elif [[ "$exact" == true || "$published" == true || "${FAKE_HEX_CHECKSUM_MISMATCH_PACKAGE:-}" == "$package" || "${FAKE_HEX_PUBLISHER_MISMATCH_PACKAGE:-}" == "$package" ]]; then
        status=200
        body="{\\\"name\\\":\\\"$package\\\",\\\"owners\\\":[{\\\"username\\\":\\\"eric.descourtis\\\"}]}"
      fi
    else
      if [[ "$exact" == true || "$published" == true || "${FAKE_HEX_CHECKSUM_MISMATCH_PACKAGE:-}" == "$package" || "${FAKE_HEX_PUBLISHER_MISMATCH_PACKAGE:-}" == "$package" ]]; then
        status=200
        publisher="eric.descourtis"
        if [[ "$published" == true && "${FAKE_HEX_POST_PUBLISH_BAD_PUBLISHER_PACKAGE:-}" == "$package" ]]; then
          publisher="somebody.else"
        fi
        if [[ "${FAKE_HEX_PUBLISHER_MISMATCH_PACKAGE:-}" == "$package" ]]; then
          publisher="somebody.else"
        fi
        if [[ "${FAKE_HEX_CHECKSUM_MISMATCH_PACKAGE:-}" == "$package" ]]; then
          checksum="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        fi
        body="{\\\"version\\\":\\\"0.1.0\\\",\\\"checksum\\\":\\\"$checksum\\\",\\\"publisher\\\":{\\\"username\\\":\\\"$publisher\\\"}}"
      fi
    fi

    printf '%s' "$body" > "$output"
    printf '%s' "$status"
    """)

    File.chmod!(fake_elixir, 0o755)
    File.chmod!(fake_mix, 0o755)
    File.chmod!(fake_curl, 0o755)

    on_exit(fn -> File.rm_rf!(root) end)

    %{
      workspace: workspace,
      release_root: release_root,
      mix: fake_mix,
      curl: fake_curl,
      elixir: fake_elixir,
      erlang_bin: erlang_bin,
      script: script,
      log: log
    }
  end

  defp run_script(fixture, arguments \\ [], extra_env \\ []) do
    env =
      [
        {"ICONVEX_PUBLISH_WORKSPACE", fixture.workspace},
        {"ICONVEX_RELEASE_ROOT", fixture.release_root},
        {"ICONVEX_PUBLISH_MIX_BIN", fixture.mix},
        {"ICONVEX_PUBLISH_CURL_BIN", fixture.curl},
        {"ICONVEX_PUBLISH_ELIXIR_BIN", fixture.elixir},
        {"ICONVEX_PUBLISH_ERLANG_BIN_DIR", fixture.erlang_bin},
        {"FAKE_ORIGINAL_WORKSPACE", fixture.workspace},
        {"FAKE_MIX_LOG", fixture.log}
      ] ++ extra_env

    System.cmd("bash", [fixture.script | arguments], env: env, stderr_to_stdout: true)
  end

  defp contexts(log, action) do
    case File.read(log) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn line ->
          case String.split(line, " ", parts: 3) do
            ["CONTEXT", ^action, path] -> [path]
            _other -> []
          end
        end)

      {:error, :enoent} ->
        []
    end
  end

  defp actions(log, action) do
    case File.read(log) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn line ->
          case String.split(line, " ", parts: 2) do
            [^action, package] -> [package]
            _other -> []
          end
        end)

      {:error, :enoent} ->
        []
    end
  end

  defp sha256(contents) do
    :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
  end
end
