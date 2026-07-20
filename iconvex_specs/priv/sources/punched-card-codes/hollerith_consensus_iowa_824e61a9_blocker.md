# Hollerith consensus Iowa profile blocker

- Catalog subject: `Hollerith consensus punched-card code` (`ENC-0546`).
- Artifact: `uiowa-punched-card-codes.html`.
- SHA-256:
  `824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18`.
- Relevant section: “The Main Line of Development, from BCD to EBCDIC,”
  before “The IBM model 026 keypunch.”
- URL: <https://homepage.cs.uiowa.edu/~jones/cards/codes.html>.

## Blocking evidence

The diagram labels four punch-row cells with `?`: two in row 0 and two in
row 2. The prose immediately after the diagram says that coding of the
positions shown with `?` varied. The chart gives no one graphic assignment
for each variant position and describes a common historical subset rather
than a versioned, fully specified 64-character profile.

## Required evidence to unblock

A codec needs a pinned, versioned primary table that uniquely specifies:

1. the graphic/function assigned to every accepted 12-bit mask, including all
   four variant cells;
2. the canonical inverse when more than one punch represents a graphic;
3. exact Unicode bindings for historical non-ASCII graphics; and
4. whether no-punch and every unlisted mask are blank, invalid, or controls.

Until that evidence exists, implementing a `Hollerith consensus` codec would
guess at source-declared variation. No logical, 16-bit, or packed identity is
registered from this row.
