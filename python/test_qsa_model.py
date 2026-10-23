"""Self-test of the QSA golden model against hand-reasoned cases."""
import numpy as np
from qsa_model import requant, tile, matmul_acc

# (acc, bias, M, S, zp, relu, expected): same 25 cases as the SystemVerilog directed test
CASES = [
    (100, 0, 1, 0, 0, 0, 100),
    (1000, 0, 1, 3, 0, 0, 125),
    (4, 0, 1, 3, 0, 0, 1),
    (-4, 0, 1, 3, 0, 0, 0),
    (3, 0, 1, 3, 0, 0, 0),
    (1000, 0, 1, 0, 0, 0, 127),
    (-1000, 0, 1, 0, 0, 0, -128),
    (-128, 0, 1, 0, 0, 0, -128),
    (127, 0, 1, 0, 0, 0, 127),
    (128, 0, 1, 0, 0, 0, 127),
    (10, 0, 1, 0, -20, 0, -10),
    (10, 0, 1, 0, -20, 1, 0),
    (100, 0, 1, 0, 100, 0, 127),
    (50, -70, 1, 0, 0, 0, -20),
    (2000000000, 2000000000, 1, 31, 0, 0, 2),
    (1, 0, 65535, 16, 0, 0, 1),
    (-2000000000, 0, 65535, 31, 0, 0, -128),
    (77, 0, 1, 0, 0, 1, 77),
    (-77, 0, 1, 0, 0, 1, 0),
    (-1000, 0, 1, 0, 0, 1, 0),
    (-10, 0, 1, 0, 20, 1, 10),
    (1073741824, 0, 1, 31, 0, 0, 1),
    (1, 0, 1, 1, 0, 0, 1),
    (-1, 0, 1, 1, 0, 0, 0),
    (500, 0, 0, 0, 5, 0, 5),
]

checks = 0
errors = 0

for acc, bias, m, s, zp, relu, exp in CASES:
    got = int(requant(acc, bias, m, s, zp, relu))
    checks += 1
    if got != exp:
        errors += 1
        print(f"ERROR requant acc={acc} bias={bias} M={m} S={s} zp={zp} relu={relu} got={got} exp={exp}")

# Hand-computed 2x2 example (same as the SystemVerilog array test)
A = [[1, 2, 3], [4, 5, 6]]
B = [[7, 8], [9, 10], [11, 12]]
C = matmul_acc(A, B)
for (i, j), exp in {(0, 0): 58, (0, 1): 64, (1, 0): 139, (1, 1): 154}.items():
    checks += 1
    if int(C[i][j]) != exp:
        errors += 1
        print(f"ERROR matmul C[{i}][{j}] got={int(C[i][j])} exp={exp}")

# Full tile path: identity-like check with bias and requant
T = tile(A, B, [0, 0], 1, 0, 0, 0)
checks += 1
if T.tolist() != [[58, 64], [127, 127]]:
    errors += 1
    print(f"ERROR tile got={T.tolist()}")

print(f"PYTHON MODEL {'OK' if errors == 0 else 'FAILED'} checks={checks} errors={errors}")
