Judge `verification_adequacy` by whether the packet's `verification` proves what its
`intent` rests on, weighed against the risk you rate:

- `adequate`: the checks reach what `safe_because` rests on, and `not_verified` leaves
  nothing material.
- `adequate with accepted gaps`: the named gaps are acceptable for that risk.
- `inadequate`: no check reaches the fact the safety claim rests on.
- `cannot judge`: the checks do not show what ran.

`weakest_claim` names the claim the evidence supports least. `next_check` names the one
check that would most raise confidence.
