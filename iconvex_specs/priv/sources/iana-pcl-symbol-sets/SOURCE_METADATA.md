# IANA PCL symbol-set source metadata

IANA registers the fourteen names implemented here but does not publish byte tables. The exact mapping facts were extracted from Artifex GhostPDL `plsymbol.c` revision `409356a1ad15aeca1280bb91aed58564c5524540`: <https://github.com/ArtifexSoftware/ghostpdl/blob/409356a1ad15aeca1280bb91aed58564c5524540/pcl/pl/plsymbol.c> (upstream SHA-256 `80f85c019f6e7de90c7e2fd804cdb0b2e74a016b4ec142e193c76f24698bb6ec`).

The upstream C source is not retained or packaged and its header points to the GhostPDL distribution license. `mappings.txt` is a repository-only normalized factual extraction, excluded from Hex; this record makes no LGPL claim over Artifex material. Iconvex's independent generator/runtime remain LGPL-2.1-or-later.

| Artifact | Derivation | SHA-256 | Disposition |
|---|---|---|---|
| `mappings.txt` | Deterministic extraction by `tools/import_iana_pcl_symbol_sets.exs` from the pinned official Artifex source | `56a7791be539271f894b6658ad6431a819dff97979fefb4cf70c5e51508c3342` | repository-only normalized mapping facts |
