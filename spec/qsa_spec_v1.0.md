\# QSA Specification v1.0 (frozen)

Quantized Systolic Array (QSA): signed INT8 tile-matrix-multiply accelerator.
Author: Blessy Evangeline S. Changes after this point need a written revision (Section 12).

\## 1. Parameters
| Name | Value |
|---|---|
| N | 4 (default, parameter; 8 optional) |
| K | 1 to 256, programmed per job |
| Operands | signed INT8 (-128 to 127) |
| Accumulator | signed 32-bit per PE |

\## 2. Operation
One job computes the tile C\[NxN] = A\[NxK] x B\[KxN], output-stationary.
Invariant: all accumulators are zero whenever busy = 0.

\## 3. Post-processing (per output element C\[i]\[j])
1\. `sum = acc + BIAS\[j]` computed in 64-bit signed, no wrap.
2\. `t = sum \* M` where M = QM\[15:0] is unsigned; 64-bit signed result.
3\. `r = t` if S = 0, else `r = (t + 2^(S-1)) >>> S` (arithmetic shift, round half up). S = QS\[4:0], range 0 to 31.
4\. `y = clamp(r + zp, -128, 127)` where zp = ZP\[7:0] is signed INT8.
5\. If CTRL.relu\_en = 1 then `y = max(y, 0)`.
Output byte is y in two's complement.

\## 4. Input stream (AXI4-Stream slave)
\- K beats per job, beat k = 0 to K-1. TDATA width = 16N bits (64 at N=4).
\- Byte i (TDATA\[8i+7:8i]) for i = 0 to N-1 holds A\[i]\[k].
\- Byte N+j (TDATA\[8(N+j)+7:8(N+j)]) for j = 0 to N-1 holds B\[k]\[j].
\- TLAST must be 1 on beat K-1 and 0 on all earlier beats.
\- TREADY is low when the DUT is idle. It may be high only while busy, in the load phase, and may drop at any time (input backpressure).

\## 5. Output stream (AXI4-Stream master)
\- N beats per successful job, row 0 first. TDATA width = 8N bits.
\- Byte j (TDATA\[8j+7:8j]) of beat i holds C\[i]\[j]. TLAST = 1 on beat N-1 only.
\- The DUT holds TVALID and TDATA stable until TREADY (standard handshake).

\## 6. Registers (AXI4-Lite, 32-bit, byte address, word-aligned)
| Addr | Name | Fields | Reset |
|---|---|---|---|
| 0x00 | CTRL | bit0 start (W, self-clearing, reads 0); bit1 soft\_reset (W, self-clearing, reads 0); bit2 relu\_en (RW) | 0 |
| 0x04 | STATUS | bit0 busy (RO); bit1 done (W1C); bit2 err\_len (W1C) | 0 |
| 0x08 | K | \[8:0] RW, upper bits read 0 | 0 |
| 0x0C | QM | \[15:0] RW, upper bits read 0 | 0 |
| 0x10 | QS | \[4:0] RW, upper bits read 0 | 0 |
| 0x14 | ZP | \[7:0] signed RW, upper bits read 0 | 0 |
| 0x18 | IRQ\_EN | bit0 RW | 0 |
| 0x20 + 4i | BIAS\[i], i = 0 to N-1 | \[31:0] signed RW | 0 |

Writes to read-only bits are ignored (response OKAY). WSTRB is ignored (full-word writes only).

\## 7. Control behavior
\- \*\*start\*\* (write 1 to CTRL.start): accepted only if busy = 0 and K is in 1 to 256. On accept: done and err\_len clear, busy sets, the load phase begins. If busy = 1 the write is ignored.
\- \*\*Illegal K\*\* (0 or above 256) at start: start is rejected, err\_len sets, busy stays 0, done stays 0.
\- \*\*Success path\*\*: load K beats, compute, drain N output beats. When the last output beat is accepted (TVALID, TREADY, TLAST all 1), done sets and busy clears in the same cycle.
\- \*\*Stream error\*\*: TLAST on a beat before K-1, or missing on beat K-1, aborts the job: busy clears, err\_len sets, done stays 0, accumulators clear, no output beats are produced.
\- \*\*soft\_reset\*\*: returns the control FSM to idle; clears accumulators, busy, done, err\_len; configuration registers (CTRL.relu\_en, K, QM, QS, ZP, IRQ\_EN, BIAS) are retained. If start and soft\_reset are written together, soft\_reset wins.
\- \*\*Hard reset\*\* (ARESETn low): all registers to reset values, all VALID outputs low, accumulators zero.
\- \*\*Interrupt\*\*: `irq = STATUS.done AND IRQ\_EN.bit0` (level).

\## 8. AXI4-Lite behavior
\- Address bits \[7:0] decoded; bits \[1:0] ignored.
\- Mapped addresses (Section 6) respond OKAY (2'b00).
\- Unmapped addresses (including 0x1C and everything from 0x20 + 4N to 0xFF) respond SLVERR (2'b10); reads return 0, writes have no effect.

\## 9. Timing
No cycle-exact latency is fixed in v1.0. The RTL phase measures the latency and records it in a revision. The testbench is transaction-level and waits on `done` with a watchdog timeout.

\## 10. Out of scope
Multi-layer scheduling, SRAM, DMA, FP formats, sparsity, K above 256, physical design.

\## 11. Known limitation
The specification is written by the same author as the RTL and the models. The dual-oracle check reduces, but does not remove, shared-misunderstanding risk.

\## 12. Additions to the planning PDF v0.1 and change log
| ID | Addition | Why |
|---|---|---|
| A1 | Register addresses and bit positions defined | PDF gave names only |
| A2 | Illegal K rejected, sets err\_len | PDF left it undefined |
| A3 | err\_len is W1C; start clears done and err\_len | Needed for back-to-back jobs |
| A4 | acc + bias computed without wrap | PDF proved only acc fits 32 bits |
| A5 | TDATA byte layout fixed (A low bytes, B high bytes) | Needed to write driver and model |
| A6 | TREADY low when idle; abort behavior defined | Defines error scenario |
| A7 | Accumulators zero whenever idle; soft vs hard reset | Makes mutant M11 observable |
| A8 | SLVERR on unmapped addresses | PDF assertion "all responses OKAY" applies to mapped addresses only |
| A9 | WSTRB ignored | Simplifies RTL |
| A10 | No cycle-exact latency in v1.0 | Measured in RTL phase |

Change log: v1.0 initial freeze.
