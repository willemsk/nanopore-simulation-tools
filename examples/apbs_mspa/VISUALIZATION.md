# Visualizing electrostatic potential maps

This guide provides basic examples for loading and visualizing APBS electrostatic potential maps (`.dx` files) in popular molecular visualization software.

## Overview

APBS generates electrostatic potential maps in OpenDX format (`.dx` files). The primary outputs for visualization are:
- `pot_Lm.dx` - Coarse grid electrostatic potential with membrane
- `pot_Sm.dx` - Fine grid electrostatic potential with membrane

These can be visualized as:
- **Isosurfaces**: 3D surfaces at constant potential values
- **Surface coloring**: Potential mapped onto protein surface

## PyMOL

### Basic visualization with isosurfaces

```bash
# Load PQR structure
load OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr

# Load electrostatic potential map
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx, pot_map

# Display protein as cartoon
show cartoon
color gray, wt_mspa_oriented_pH7.0

# Create positive potential isosurface (red, +1 kT/e)
isosurface pos_pot, pot_map, 1.0
color red, pos_pot
set transparency, 0.3, pos_pot

# Create negative potential isosurface (blue, -1 kT/e)
isosurface neg_pot, pot_map, -1.0
color blue, neg_pot
set transparency, 0.3, neg_pot
```

## VMD (Visual Molecular Dynamics)

### Basic isosurface display

```bash
# Load PQR structure
mol new OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr

# Load potential map
mol addfile OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx

# Display protein as NewCartoon
mol modstyle 0 0 NewCartoon
mol modcolor 0 0 Structure

# Create positive isosurface
mol addrep 0
mol modstyle 1 0 Isosurface 1.0 0 0 0 1 1
mol modcolor 1 0 Volume 0
mol modmaterial 1 0 Transparent

# Create negative isosurface
mol addrep 0
mol modstyle 2 0 Isosurface -1.0 0 0 0 1 1
mol modcolor 2 0 Volume 0
mol modmaterial 2 0 Transparent
```

## UCSF ChimeraX

### Basic visualization

```bash
# Open files
open OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr
open OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx

# Show molecular surface
surface #1
color #1 tan

# Create isosurfaces from potential
volume #2 level 1.0 color red transparency 0.3
volume #2 level -1.0 color blue transparency 0.3

# Color molecular surface by potential
color electrostatic #1 map #2 palette -10,blue:0,white:10,red
```

## Typical contour levels

Electrostatic potential is typically measured in **kT/e** (thermal energy per elementary charge):
- At 25°C: 1 kT/e ≈ 25.7 mV
- Typical biological range: -10 to +10 kT/e

**Suggested isosurface levels:**
- **±1 kT/e**: Moderate potential (standard visualization)
- **±3 kT/e**: Strong potential (highlights highly charged regions)
- **±5 kT/e**: Very strong potential (protein active sites, binding pockets)

**Color conventions:**
- **Red**: Positive potential (attracts anions, repels cations)
- **Blue**: Negative potential (attracts cations, repels anions)
- **White/gray**: Neutral (zero potential)

## Tips

**File size management:**
- Load `pot_Sm.dx` for high-resolution visualization
- Use `pot_Lm.dx` for quick preview (smaller file)
- Fine grid files can be >300 MB - may be slow to load

**Performance:**
- Start with coarse grid calculations for testing
- Use transparency sparingly (computationally expensive)

**Color scales:**
- Adjust range to highlight features of interest
- Symmetric scales (e.g., -5 to +5 kT/e) show positive/negative balance

**Publication quality:**
- Use ray tracing for final images (`ray` in PyMOL, `render` in ChimeraX)
- Include scale bar for potential values
- Label key structural features

## Further resources

- **PyMOL APBS Tools**: https://pymolwiki.org/index.php/APBS
- **VMD APBS Plugin**: https://www.ks.uiuc.edu/Research/vmd/plugins/apbsrun/
- **Chimera Electrostatics**: https://www.cgl.ucsf.edu/chimera/docs/ContributedSoftware/apbs/apbs.html
- **OpenDX Format**: https://web.archive.org/web/20080808140524/http://opendx.sdsc.edu/docs/html/pages/usrgu068.html
