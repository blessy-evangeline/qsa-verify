\# QSA Verification Plan (vPlan) v1.0

Every requirement maps to at least one coverage item or assertion and at least one test. Status column is updated as evidence is produced.

\## 1. Requirements to evidence
| Req | Requirement | Evidence (coverage / assertion / test) | Mutants | Status |
|---|---|---|---|---|
| R1 | Signed INT8 multiply correct for all sign combinations | CG\_operands sign cross; qsa\_random\_test, qsa\_extremes\_test | M1 | Planned |
| R2 | Accumulation exact for K = 1 to 256 | CG\_cfg K bins (1, 2, 3-8, 9-64, 65-255, 256) | M2, M6 | Planned |
| R3 | Per-column bias added exactly once | CG\_cfg bias sign/zero bins | M7 | Planned |
| R4 | Requantization multiply, shift, rounding, zero-point | CG\_cfg shift bins; directed tie test | M3 | Planned |
| R5 | Saturation at both ends | CG\_result sat\_low / sat\_high | M4 | Planned |
| R6 | ReLU behavior | CG\_result relu x sign cross | M5 | Planned |
| R7 | Input stream protocol, TLAST position, error flagging, illegal K | SVA\_AXIS\_IN; qsa\_error\_test | M8 | Planned |
| R8 | Output order and TLAST correct | Scoreboard order check; SVA\_AXIS\_OUT | M8, M10 | Planned |
| R9 | No data loss under backpressure | CG\_stream ready-delay bins; stability SVA; qsa\_backpressure\_test | M9 | Planned |
| R10 | AXI-Lite handshake rules; OKAY (mapped) and SLVERR (unmapped) | SVA\_AXIL; qsa\_reg\_test | M14 | Planned |
| R11 | Register map: reset values, read-only, W1C, self-clearing start | qsa\_reg\_test; CG\_reg | M13, M15 | Planned |
| R12 | Reset (soft/hard) at any phase returns DUT to idle, clean state | CG\_reset phase bins; qsa\_reset\_test | M11 | Planned |
| R13 | Back-to-back jobs; start-while-busy ignored | qsa\_b2b\_test; CG\_cfg | M12, M16 | Planned |
| R14 | Interrupt semantics | SVA\_DUT irq rule; IRQ test | - | Planned |

\## 2. Covergroups
| Name | Sampled from | Contents |
|---|---|---|
| CG\_operands | input stream monitor | A and B value bins {-128, -127, -64..-2, -1, 0, 1, 2..63, 126, 127}; A-sign x B-sign; extreme x extreme |
| CG\_cfg | AXI-Lite monitor | K bins; shift bins {0, 1, 2..15, 16..30, 31}; multiplier bins; zp bins; relu on/off; K x relu |
| CG\_result | scoreboard | pre-clamp region {below -128, within, above 127}; exact-tie flag; relu x sign |
| CG\_stream | stream monitors | VALID gap lengths; READY stall lengths; one-cycle-stall bin; TLAST position |
| CG\_reg | AXI-Lite monitor | address x {read, write} x {OKAY, SLVERR}; W1C write; write to read-only |
| CG\_reset | reset monitor | reset during {idle, load, compute, drain, done-pending} |

\## 3. Assertions (target 20+, each with a cover property)
| Group | Count | Rules |
|---|---|---|
| AXI-Lite | 8 | VALIDs hold until READY; BVALID/RVALID hold; RDATA stable while stalled; OKAY on mapped, SLVERR on unmapped; no RVALID without accepted AR |
| AXI-Stream IN | 3 | TVALID holds until TREADY; TDATA/TLAST stable while stalled; TLAST only on beat K-1 when K is valid |
| AXI-Stream OUT | 4 | TVALID holds; data stable while stalled; exactly N beats per job; TLAST only on last beat |
| DUT behavior | 5 | no output before start; done sets once per job; busy high from start until done; irq = done AND irq\_en; err\_len only after bad TLAST or illegal K |
| Reset | 2 | VALID outputs low after reset; busy low after reset |

\## 4. Tests (selected with +UVM\_TESTNAME)
qsa\_sanity\_test, qsa\_random\_test, qsa\_extremes\_test, qsa\_backpressure\_test, qsa\_error\_test, qsa\_reset\_test, qsa\_b2b\_test, qsa\_reg\_test, qsa\_vector\_replay\_test, qsa\_realmodel\_test.

\## 5. Exit criteria (targets, not results)
Functional coverage 95% or more with documented exclusions; 0 scoreboard mismatches over 10,000+ tiles; 20+ assertions; mutation score 85-90% or more of non-equivalent mutants; real-model logits identical to Python INT8. All numbers are reported only after measurement.
