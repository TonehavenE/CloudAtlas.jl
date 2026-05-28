# Symmetry Notation Mapping

This note records the current working map between the CloudAtlas symmetry
notation, the Gibson-Halcrow-Cvitanovic (GHC) notation, and the Sharma 2020
labels used in the equilibrium literature catalog.

The key point is that some literature groups are equal to our A-G groups, while
others are only conjugate to them by a spatial shift. That distinction matters
for symmetry-constrained searches: a conjugate subgroup describes the same
physical class up to phase convention, but it is not the same invariant subspace
in the code.

## CloudAtlas Primitive Symmetries

CloudAtlas represents the half-box symmetry generators as `sx`, `sy`, `sz`,
`tx`, and `tz`.

| CloudAtlas symbol | Meaning |
| --- | --- |
| `tx` | half-box shift in `x`, `tau(Lx/2, 0)` |
| `tz` | half-box shift in `z`, `tau(0, Lz/2)` |
| `txz` | `tx * tz = tau(Lx/2, Lz/2)` |
| `sxy` | GHC/Sharma `sigma_x`; reflection in `x,y` |
| `sz` | GHC/Sharma `sigma_z`; reflection in `z` |
| `sxyz` | `sxy * sz`, GHC/Sharma `sigma_xz` |
| `sxytz` | `sxy * tz` |
| `sztx` | `sz * tx` |
| `sztxz` | `sz * tx * tz = sz * txz` |

In the manuscript notation, `sigma_xyz = sigma_xy sigma_z` and
`tau_xz = tau_x tau_z`. The GHC/Sharma naming convention in the current
literature comparison is:

```text
sigma_x^GHC  = sxy
sigma_z^GHC  = sz
sigma_xz^GHC = sxyz
```

## Current CloudAtlas A-G Groups

These are the groups currently used by the equilibrium discovery scripts.

| Group | Generators | Expanded notation |
| --- | --- | --- |
| `A` | `<sxyz, txz>` | `<sigma_xz, tau_xz>` |
| `B` | `<sxy, sz>` | `<sigma_x, sigma_z>` |
| `C` | `<sxytz, sz>` | `<sigma_x tau_z, sigma_z>` |
| `D` | `<sxy, sztx>` | `<sigma_x, sigma_z tau_x>` |
| `E` | `<sxyz, sztxz>` | `<sigma_xz, sigma_z tau_xz>` |
| `F` | `<sxy, sz, txz>` | `<sigma_x, sigma_z, tau_xz>` |
| `G` | `<sxyz>` | `<sigma_xz>` |

## Literature Groups

### GHC `S` and Sharma `Sigma`

GHC defines

```text
S = {e, sigma_z tau_x, sigma_x tau_xz, sigma_xz tau_z}
```

In CloudAtlas notation:

```text
S_GHC = Sigma_Sharma
      = {e, sztx, sxy*txz, sxyz*tz}
      = <sztx, sxy*txz>
```

This is not exactly our group `E`. It is conjugate to GHC's simpler canonical
`R_xz`, which is our `E`:

```text
R_xz = {e, sigma_x tau_xz, sigma_z tau_xz, sigma_xz}
     = {e, sxy*txz, sztxz, sxyz}
     = E
```

Working rule:

```text
GHC S = Sharma Sigma != E exactly
GHC S is conjugate to E
```

For catalog matching, this is strong evidence of the same physical symmetry
class. For exact searches in the GHC/Sharma phase convention, use
`<sztx, sxy*txz>`, not `E`.

### GHC `S x {e, tau_xz}` and Sharma `Theta`

Expanding GHC's shift-extended group gives:

```text
S_GHC x {e, txz}
  = {e, sztx, sxy*txz, sxyz*tz,
     txz, sz*tz, sxy, sxyz*tx}
```

A compact generator form is:

```text
Theta_Sharma = S_GHC x {e, txz}
             = <sztx, sxy*txz, txz>
             = <sxy, sztx, txz>
```

This is not exactly our group `F`. Our `F` is:

```text
F = <sxy, sz, txz>
  = R x {e, txz}
```

Working rule:

```text
Sharma Theta = GHC S x {e, tau_xz} != F exactly
Sharma Theta is conjugate to F
```

For exact searches in the GHC/Sharma phase convention, use
`<sxy, sztx, txz>`, not `F`.

### Sharma `Theta6`

The current working interpretation is:

```text
Theta6 = <sxyz*tz>
```

This group is not currently one of the A-G search groups as an exact named
subspace.

### Sharma `K`

The current working interpretation is:

```text
K = <sxy, sz> = B
```

This maps exactly to the CloudAtlas `B` group.

### GHC `{e, sigma_xz}`

GHC's order-two class maps directly to:

```text
{e, sigma_xz^GHC} = {e, sxyz} = G
```

This maps exactly to the CloudAtlas `G` group.

## Recommended Search Labels To Add

The current A-G groups are enough for the canonical/conjugate classes, but not
for exact GHC/Sharma phase-convention searches. Useful named additions would be:

| Proposed label | Generators | Purpose |
| --- | --- | --- |
| `SigmaGHC` | `<sztx, sxy*txz>` | exact GHC `S` / Sharma `Sigma` |
| `ThetaGHC` | `<sxy, sztx, txz>` | exact GHC `S x {e, tau_xz}` / Sharma `Theta` |
| `Theta6` | `<sxyz*tz>` | exact Sharma `Theta6` |
| `K` | alias for `B` | exact Sharma `K` |
| `Rxz` | alias for `E` | canonical GHC `R_xz` |

The practical search matrix after adding these labels would be:

```text
Sharma Sigma / GHC S                 -> SigmaGHC
Sharma Theta / GHC S x {e,tau_xz}    -> ThetaGHC
Sharma Theta6                        -> Theta6
Sharma K                             -> B or K
GHC {e,sigma_xz}                     -> G
canonical R_xz                       -> E or Rxz
canonical R x {e,tau_xz}             -> F
```

## Catalog Interpretation

For literature mapping, record both:

```text
exact_symmetry_generators
canonical_conjugacy_class
```

Example:

```text
GHC S / Sharma Sigma:
  exact_symmetry_generators = <sztx, sxy*txz>
  canonical_conjugacy_class = E

GHC S x {e,tau_xz} / Sharma Theta:
  exact_symmetry_generators = <sxy, sztx, txz>
  canonical_conjugacy_class = F
```

This avoids conflating exact invariant subspaces with physically equivalent
conjugacy classes.
