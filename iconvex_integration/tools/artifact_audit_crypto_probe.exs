Code.require_file("artifact_audit_support.exs", __DIR__)

for path <- :code.get_path(),
    path = List.to_string(path),
    Path.basename(path) == "ebin",
    Path.basename(Path.dirname(path)) |> String.starts_with?("crypto-") do
  :code.del_path(String.to_charlist(path))
end

:code.purge(:crypto)
:code.delete(:crypto)

before? = Code.ensure_loaded?(:crypto)
IconvexIntegration.ArtifactAuditSupport.ensure_crypto!()
after? = Code.ensure_loaded?(:crypto)
digest_size = apply(:crypto, :hash, [:sha256, "artifact-audit-probe"]) |> byte_size()

IO.puts(
  "artifact audit crypto probe: before=#{before?} after=#{after?} sha256_bytes=#{digest_size}"
)
