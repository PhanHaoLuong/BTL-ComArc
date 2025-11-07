import numpy as np

desired = [0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5, 0.0]
input   = [0.1, 0.6, 0.9, 0.4, 0.1, -0.6, -0.8, -0.4, 0.1]
M = 3


dSz = len(desired)
iSz = dSz



if dSz != iSz:
    print("Invalid input")
else:
    print("OK!")

gamma_xx = [0.0 for i in range(M)]
for i in range(M):
    sum = 0
    for j in range(i, iSz):
        sum += input[j] * input[j - i]
    gamma_xx[i] = sum / (iSz - j)

gamma_dx = [0.0 for i in range(M)]
for i in range(M):
    sum = 0
    for j in range(i, iSz):
        sum += desired[j] * input[j - i]
    gamma_dx[i] = sum / (dSz - j)

R = [[0.0 for i in range(M)] for i in range(M)]

for i in range(M):
    for j in range(M):
        lag = abs(i - j)
        R[i][j] = gamma_xx[lag]

h = np.linalg.solve(R, gamma_dx)
print("Coefficients h are:", h)

output = [0.0 for i in range(iSz)]
for i in range(iSz):
    sum = 0
    for k in range(0, M):
        if i - k >= 0:
            sum += h[k] * input[i - k]
    output[i] = float(np.round(sum, 1))
print("Output:", output)

mmse = 0
for i in range(iSz):
    diff = desired[i] - output[i]
    mmse += pow(diff, 2)
mmse = mmse / iSz
print("MMSE:", mmse)
