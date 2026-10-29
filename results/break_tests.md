# Break tests (manual mutation checks)

Each row is a deliberate bug put into a copy of the design. The block's testbench was then run against that copy. A testbench that cannot fail proves nothing, so every one of these must produce failures, and every one did. The original, unbroken design passes all of its checks (see `results/logs/SUMMARY.txt`).

| Block | Bug injected | Related catalog mutant | Failing checks | Total checks |
|---|---|---|---|---|
| MAC (UVM warm-up) | accumulate with `-` instead of `+` | warm-up, not in catalog | 42 | 50 |
| Systolic array | A-row input skew removed | not in catalog | 663 | 928 |
| Requantization | round-half-up removed (truncate) | M3 | 7 | 25 |
| Control core | drain wait set to 0 cycles | control timing, not in catalog | 7 | 83 |
| Register block | write-1-to-clear on `done` never fires | M15 | 2 | 101 |
| Top level | `done_clr` wire tied low | M15 (through wiring) | 9 | 83 |

## What this is, and is not

- These are 6 hand-made breaks, run one at a time. They are not the automated 16-mutant score from the project plan.
- The full mutation harness (Python, 16 mutants, killed / survived table) comes in Phase 6 and will replace this table.
- One lesson already learned: the core drain-wait bug was caught only by the always-ready output job (7 of 83 checks). Random output stalls give the array extra time and hide it. The UVM environment must keep an always-ready test.
