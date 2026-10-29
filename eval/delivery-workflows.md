# Capture workflow declarations

`DeliveryWorkflows` reads the `.github/workflows` directory at a full fixture
commit and supplies D2's `pinned_actions` declarations. It does not establish
which Actions executed or qualify a delivery controller.

```ruby
require_relative 'lib/shaka/evaluation/delivery_workflows'

snapshot = Shaka::Evaluation::DeliveryWorkflows.new(
  repository: fixture_repository, head: expected_head, github: absolute_gh_path
).read
fingerprint['pinned_actions'] = snapshot.fetch('pinned_actions')
```

The receipt retains repository, head, native directory tree ID, workflow blob IDs
and a host-monotonic observation time. It discards source text. The reader
recomputes Git tree and blob identities from the returned inventory and bytes;
missing entries or altered text cannot silently establish a complete inventory.
It reads immediate `.yml` and `.yaml` files; nested directories are not workflows.

For literal remote `uses` references at ordinary job or step positions, the
`pinned_actions` map associates file, location and Action path with the declared
40-character commit. Different locations retain different revisions of one Action.
An empty map means supported workflow syntax declared no references.
This is a declaration inventory, not a GitHub syntax validator. It does not resolve
transitive dependencies inside called Actions or reusable workflows.

Any mutable tag or branch, expression, local reference, Docker reference or
unrecognized `uses` location makes the entire field `UNKNOWN`. Ambiguous mappings,
aliases, anchors, explicit YAML tags, multiple documents and malformed YAML also
remain unknown. The parser visits syntax nodes without deserializing objects.
Its bounds are 10,000 visited nodes and 40 nesting levels.

Unavailable or inconsistent native data raises `IOError`. The native directory
limit is 100 entries. The reused transport limits the complete response to 1 MiB,
including all returned directory blob texts and JSON overhead together. Requests
share its maximum 30-second budget, with subprocess cleanup outside the timer.
Missing directories, symlink workflows, binary or truncated text cannot qualify.

Retain receipts privately outside agent mounts. Use `UNKNOWN` to keep a comparison
provisional; a requested pin cannot replace observed source. The remaining D2
fields, executed-job provenance, terminal/tool capture, hidden verification,
controller qualification and release verdicts remain separate work. No model,
paid trial or schedule runs through this API.

GitHub documents [workflow locations and `uses` forms](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsuses).
