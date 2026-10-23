# QSA Verification Plan (vPlan) v1.0

Every requirement maps to at least one coverage item or assertion, and at least one test. The Status column is updated as evidence is produced.

## 1. Requirements to evidence

| Req | Requirement | Evidence (coverage / assertion / test) | Mutants | Status |
|---|---|---|---|---|
| R1 | Signed INT8 multiply correct for all sign combinations | CG_operands sign cross; qsa_random_test, qsa_extremes_test | M1 | Planned |
| R2 | Accumulation exact for K = 1 to 256 | CG_cfg K bins (1, 2, 3-8, 9-64, 65-255, 256) | M2, M6 | Planned |
| R3 | Per-column bias added exactly once | CG_cfg bias sign/zero bins | M7 | Planned |
| R4 | Requantization multiply, shift, rounding, zero-point | CG_cfg shift bins; directed tie test | M3 | Planned |
| R5 | Saturation at both ends | CG_result sat_low / sat_high | M4 | Planned |
| R6 | ReLU behavior | CG_result relu x sign cross | M5 | Planned |
| R7 | Input stream protocol, TLAST position, error flagging, illegal K | SVA_AXIS_IN; qsa_error_test | M8 | Planned |
| R8 | Output order and TLAST correct | Scoreboard order check; SVA_AXIS_OUT | M8, M10 | Planned |
| R9 | No data loss under backpressure | CG_stream ready-delay bins; stability SVA; qsa_backpressure_test | M9 | Planned |
| R10 | AXI-Lite handshake rules; OKAY (mapped) and SLVERR (unmapped) | SVA_AXIL; qsa_reg_test | M14 | Planned |
| R11 | Register map: reset values, read-only, W1C, self-clearing start | qsa_reg_test; CG_reg | M13, M15 | Planned |
| R12 | Reset (soft/hard) at any phase returns DUT to idle with clean state | CG_reset phase bins; qsa_reset_test | M11 | Planned |
| R13 | Back-to-back jobs; start-while-busy ignored | qsa_b2b_test; CG_cfg | M12, M16 | Planned |
| R14 | Interrupt semantics | SVA_DUT irq rule; IRQ test | - | Planned |

## 2. Covergroups

| Name | Sampled from | Contents |
|---|---|---|
| CG_operands | input stream monitor | A and B value bins {-128, -127, -64..-2, -1, 0, 1, 2..63, 126, 127}; A-sign x B-sign; extreme x extreme |
| CG_cfg | AXI-Lite monitor | K bins; shift bins {0, 1, 2..15, 16..30, 31}; multiplier bins; zp bins; relu on/off; K x relu |
| CG_result | scoreboard | pre-clamp region {below -128, within, above 127}; exact-tie flag; relu x sign |
| CG_stream | stream monitors | VALID gap lengths; READY stall lengths; one-cycle-stall bin; TLAST position |
| CG_reg | AXI-Lite monitor | address x {read, write} x {OKAY, SLVERR}; W1C write; write to read-only |
| CG_reset | reset monitor | reset during {idle, load, compute, drain, done-pending} |

## 3. Assertions (target 20+, each with a cover property)

| Group | Count | Rules |
|---|---|---|
| AXI-Lite | 8 | VALIDs hold until READY; BVALID/RVALID hold; RDATA stable while stalled; OKAY on mapped, SLVERR on unmapped; no RVALID without an accepted AR |
| AXI-Stream IN | 3 | TVALID holds until TREADY; TDATA/TLAST stable while stalled; TLAST only on beat K-1 when K is valid |
| AXI-Stream OUT | 4 | TVALID holds; data stable while stalled; exactly N beats per job; TLAST only on the last beat |
| DUT behavior | 5 | no output before start; done sets once per job; busy high from start until done; irq = done AND irq_en; err_len only after bad TLAST or illegal K |
| Reset | 2 | VALID outputs low after reset; busy low after reset |

## 4. Tests (selected with +UVM_TESTNAME)

qsa_sanity_test, qsa_random_test, qsa_extremes_test, qsa_backpressure_test, qsa_error_test, qsa_reset_test, qsa_b2b_test, qsa_reg_test, qsa_vector_replay_test, qsa_realmodel_test.

## 5. Exit criteria (targets, not results)

- Functional coverage 95% or more, with documented exclusions.
- 0 scoreboard mismatches over 10,000+ tiles.
- 20+ assertions.
- Mutation score 85-90% or more of non-equivalent mutants.
- Real-model logits identical to the Python INT8 reference.

All numbers are reported only after they are measured.
