"""QSA golden model (spec v1.0), written from the specification only.

All arithmetic uses int64. Independent of the RTL and of the SystemVerilog model.
"""
import numpy as np


def requant(acc, bias, m, s, zp, relu):
    """Requantize accumulators to INT8 (spec Section 3). Inputs may be scalars or arrays."""
    acc = np.asarray(acc, dtype=np.int64)
    bias = np.asarray(bias, dtype=np.int64)
    m = np.asarray(m, dtype=np.int64)
    s = np.asarray(s, dtype=np.int64)
    zp = np.asarray(zp, dtype=np.int64)

    total = acc + bias                         # 64-bit, no wrap
    t = total * m                              # M is unsigned 16-bit
    rnd = np.where(s > 0, np.int64(1) << np.maximum(s - 1, 0), 0)
    r = (t + rnd) >> s                         # arithmetic shift, round half up
    y = np.clip(r + zp, -128, 127)
    if relu:
        y = np.maximum(y, 0)
    return y.astype(np.int64)


def tile(a, b, bias, m, s, zp, relu):
    """One job: C = A (NxK) x B (KxN), per-column bias, requantize. Returns NxN INT8 values."""
    a = np.asarray(a, dtype=np.int64)
    b = np.asarray(b, dtype=np.int64)
    acc = a @ b                                # exact INT32-range accumulation
    return requant(acc, np.asarray(bias, dtype=np.int64)[np.newaxis, :], m, s, zp, relu)


def matmul_acc(a, b):
    """Raw accumulator tile, before requantization."""
    return np.asarray(a, dtype=np.int64) @ np.asarray(b, dtype=np.int64)
