# glibc IBM423 oracle

Pinned revision: `e5145be467bed28bafde33a51df97840be37065e`.

- User-supplied implementation URL: https://gitlab.opencode.de/CoDE_Admin/glibc/-/blob/e5145be467bed28bafde33a51df97840be37065e/iconvdata/ibm423.c
- Byte-identical mirror used for retrieval: https://raw.githubusercontent.com/bminor/glibc/e5145be467bed28bafde33a51df97840be37065e/iconvdata/ibm423.c
- Generated-table source: https://raw.githubusercontent.com/bminor/glibc/e5145be467bed28bafde33a51df97840be37065e/localedata/charmaps/IBM423

SHA-256:

- `ibm423.c`: `0d1f50f21a2b7ec6375e1ad8a35258b3993d0220b7d4089fb0408e229ae67067`
- `IBM423`: `8c5890f6c82ceef0231fd61f4bd661e1fd8cadd88e1944be2b31c967a9f1e02e`

`ibm423.c` includes generated `ibm423.h`; glibc builds that table from
`localedata/charmaps/IBM423`. Tests parse all 246 defined byte positions from
that charmap and verify decode plus canonical encode against Iconvex Specs.
