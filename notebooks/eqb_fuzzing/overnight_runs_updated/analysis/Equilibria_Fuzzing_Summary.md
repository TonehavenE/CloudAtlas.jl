# EQB Fuzzing Thrust Summary (Concise)

Generated: 2026-03-10 20:32:37

Scope: four overnight runs (`Re=300/400`, boxes `10x6` and `2πxπ`) using the `(1,3,5)` fuzz stage followed by promotion and DNS `findsoln`.

## 1) Hookstep Convergence and Unique EQB at (1,3,5)
Values are `hookstep_converged / 100000` initial guesses, plus unique EQB count at `(J,K,L)=(1,3,5)`.

### re300_lx10_lz6 (Re=300, Lx=10, Lz=6)

| Group | Hookstep Converged (/100000) | Unique EQB |
|---|---:|---:|
| A | 10080 | 2 |
| B | 39869 | 4 |
| C | 16958 | 6 |
| D | 26064 | 4 |
| E | 18335 | 6 |
| F | 51052 | 1 |
| G | 1795 | 11 |

### re300_lx2pi_lzpi (Re=300, Lx=2π, Lz=π)

| Group | Hookstep Converged (/100000) | Unique EQB |
|---|---:|---:|
| A | 1305 | 3 |
| B | 11899 | 3 |
| C | 7012 | 3 |
| D | 16673 | 3 |
| E | 9162 | 8 |
| F | 23893 | 2 |
| G | 207 | 3 |

### re400_lx10_lz6 (Re=400, Lx=10, Lz=6)

| Group | Hookstep Converged (/100000) | Unique EQB |
|---|---:|---:|
| A | 5034 | 8 |
| B | 26998 | 4 |
| C | 10708 | 10 |
| D | 18648 | 9 |
| E | 11326 | 16 |
| F | 39345 | 2 |
| G | 613 | 9 |

### re400_lx2pi_lzpi (Re=400, Lx=2π, Lz=π)

| Group | Hookstep Converged (/100000) | Unique EQB |
|---|---:|---:|
| A | 389 | 5 |
| B | 6927 | 4 |
| C | 3510 | 7 |
| D | 11721 | 6 |
| E | 4359 | 7 |
| F | 18554 | 4 |
| G | 25 | 6 |

## 2) DNS Solutions Recovered from Those EQB Seeds
`DNS converged sol IDs` counts converged `sol###` tracks; `DNS unique states` is deduplicated by `(shear, L2)` within each case+group.

### re300_lx10_lz6 (Re=300, Lx=10, Lz=6)

| Group | DNS converged sol IDs | DNS unique states |
|---|---:|---:|
| A | 2 | 2 |
| B | 2 | 2 |
| C | 6 | 5 |
| D | 4 | 4 |
| E | 5 | 3 |
| F | 1 | 1 |
| G | 8 | 6 |
| **Total** | **28** | **23** |

### re300_lx2pi_lzpi (Re=300, Lx=2π, Lz=π)

| Group | DNS converged sol IDs | DNS unique states |
|---|---:|---:|
| A | 2 | 1 |
| B | 3 | 3 |
| C | 3 | 2 |
| D | 3 | 3 |
| E | 8 | 4 |
| F | 2 | 2 |
| G | 3 | 2 |
| **Total** | **24** | **17** |

### re400_lx10_lz6 (Re=400, Lx=10, Lz=6)

| Group | DNS converged sol IDs | DNS unique states |
|---|---:|---:|
| A | 4 | 4 |
| B | 4 | 3 |
| C | 7 | 6 |
| D | 5 | 4 |
| E | 11 | 7 |
| F | 2 | 2 |
| G | 7 | 6 |
| **Total** | **40** | **32** |

### re400_lx2pi_lzpi (Re=400, Lx=2π, Lz=π)

| Group | DNS converged sol IDs | DNS unique states |
|---|---:|---:|
| A | 3 | 2 |
| B | 3 | 3 |
| C | 4 | 3 |
| D | 2 | 2 |
| E | 4 | 2 |
| F | 2 | 2 |
| G | 6 | 2 |
| **Total** | **24** | **16** |

## 3) High-Shear DNS States Worth Follow-Up
Filtered to `shear >= 1.5` from deduplicated converged DNS catalog.

| Rank | Case | Group | Unique ID | Shear | L2 | Multiplicity | Members |
|---:|---|---|---|---:|---:|---:|---|
| 1 | re400_lx2pi_lzpi | C | u003 | 4.39284 | 0.43619 | 1 | `sol005@J1K3L5` |
| 2 | re400_lx2pi_lzpi | F | u002 | 4.39284 | 0.43619 | 1 | `sol003@J1K3L5` |
| 3 | re300_lx2pi_lzpi | A | u001 | 3.7039 | 0.419643 | 2 | `sol001@J3K5L11;sol003@J1K3L5` |
| 4 | re300_lx2pi_lzpi | B | u003 | 3.7039 | 0.419643 | 1 | `sol003@J1K3L5` |
| 5 | re300_lx2pi_lzpi | C | u002 | 3.7039 | 0.419643 | 1 | `sol003@J1K3L5` |
| 6 | re300_lx2pi_lzpi | E | u004 | 3.7039 | 0.419643 | 1 | `sol007@J1K3L5` |
| 7 | re300_lx2pi_lzpi | F | u002 | 3.7039 | 0.419643 | 1 | `sol002@J1K3L5` |
| 8 | re300_lx2pi_lzpi | D | u003 | 3.03859 | 0.386379 | 1 | `sol001@J2K4L6` |
| 9 | re300_lx2pi_lzpi | E | u003 | 1.80947 | 0.382856 | 3 | `sol001@J3K5L11;sol006@J1K4L5;sol008@J1K3L5` |
| 10 | re300_lx10_lz6 | A | u002 | 1.75755 | 0.337678 | 1 | `sol002@J2K4L5` |
| 11 | re300_lx10_lz6 | C | u005 | 1.50822 | 0.307106 | 1 | `sol003@J2K4L6` |

Notes:
- Strongest shear observed: `4.39284` in `re400_lx2pi_lzpi` (groups `C` and `F`), and `3.7039` in `re300_lx2pi_lzpi` (multiple groups).
- In the `10x6` box, notable high-shear candidates include `A/u002` (`1.75755`) and `C/u005` (`1.50822`) at `Re=300`; a near-threshold `Re=400` candidate is `C/u006` (`1.41046`).
