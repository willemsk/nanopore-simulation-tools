# Visualizing Electrostatic Potential Maps

This guide provides command snippets for loading and visualizing APBS electrostatic potential maps (`.dx` files) in popular molecular visualization software.

## Overview

APBS generates electrostatic potential maps in OpenDX format (`.dx` files). The primary outputs for visualization are:
- `pot_Lm.dx` - Coarse grid electrostatic potential with membrane
- `pot_Sm.dx` - Fine grid electrostatic potential with membrane

These can be visualized as:
- **Isosurfaces**: 3D surfaces at constant potential values
- **Volume rendering**: Continuous potential field
- **Surface coloring**: Potential mapped onto protein surface
- **Slice planes**: 2D cross-sections through the potential

## PyMOL

### Loading structure and potential

```python
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

### Surface coloring by potential

```python
# Load structure and map
load OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx, pot_map

# Generate molecular surface
show surface

# Color surface by electrostatic potential
ramp_new e_ramp, pot_map, [-10, 0, 10], [blue, white, red]
set surface_color, e_ramp
```

### Comparing pH conditions

```python
# Load structures at different pH
load OUTPUT/pqr/wt_mspa_oriented_pH6.0.pqr
load OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr
load OUTPUT/pqr/wt_mspa_oriented_pH8.0.pqr

# Load corresponding potentials
load OUTPUT/apbs_runs/wt_mspa_oriented_pH6.0_0.15M/pot_Lm.dx, pot_pH6
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx, pot_pH7
load OUTPUT/apbs_runs/wt_mspa_oriented_pH8.0_0.15M/pot_Lm.dx, pot_pH8

# Create isosurfaces at same contour level
isosurface surf_pH6, pot_pH6, 1.0
isosurface surf_pH7, pot_pH7, 1.0
isosurface surf_pH8, pot_pH8, 1.0

# Color differently
color red, surf_pH6
color green, surf_pH7
color blue, surf_pH8
```

## VMD (Visual Molecular Dynamics)

### Loading and displaying

```tcl
# Load PQR structure
mol new OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr

# Load potential map
mol addfile OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx

# Display protein as NewCartoon
mol modstyle 0 0 NewCartoon
mol modcolor 0 0 Structure

# Create isosurface representation
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

### Volume slice visualization

```tcl
# Load structure and map
mol new OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr
mol addfile OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx

# Create volume slice along Z-axis
mol addrep 0
mol modstyle 1 0 VolumeSlice 0.500000 2.000000 0.000000
mol modcolor 1 0 Volume 0

# Adjust color scale
mol scaleminmax 0 1 -10 10
```

### Scripted analysis

```tcl
# Calculate potential along pore axis (Z-direction)
# Requires voltool or similar VMD plugin

set mol [molinfo top]
set sel [atomselect $mol "all"]

# Sample potential along Z from -50 to 50 Å
set output [open "potential_profile.dat" w]
for {set z -50} {$z <= 50} {incr z 1} {
    # Get potential at (0, 0, z)
    set pot [measure volslice $mol 1 [list 0 0 $z] [list 0 0 1] 0.1]
    puts $output "$z $pot"
}
close $output
```

## UCSF Chimera / ChimeraX

### Chimera (Classic)

```python
# Via GUI: File → Open → select PQR file
# Then: Tools → Volume Data → Electrostatic Surface Coloring

# Or via command line:
open OUTPUT/pqr/wt_mspa_oriented_pH7.0.pqr
open OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx

# Show protein surface
surface
color bymodel

# Color surface by potential
scolor #1 volume #0 cmap -10,red:0,white:10,blue
```

### ChimeraX (Modern)

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

## Comparing different conditions

### pH effects

```python
# PyMOL: Compare potentials at different pH
# Load all potentials
load OUTPUT/apbs_runs/wt_mspa_oriented_pH6.0_0.15M/pot_Lm.dx, pH6
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx, pH7
load OUTPUT/apbs_runs/wt_mspa_oriented_pH8.0_0.15M/pot_Lm.dx, pH8

# Create difference maps (requires PyMOL APBS plugin or external processing)
# Alternatively, visualize side-by-side
```

### Ionic strength effects

```python
# PyMOL: Compare different ionic strengths
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.05M/pot_Lm.dx, ionc_05
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx, ionc_15
load OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.30M/pot_Lm.dx, ionc_30

# Higher ionic strength = more screening = shorter-range potential
```

## Quantitative analysis

### Extracting potential values

**Python with NumPy:**
```python
import numpy as np

# Read OpenDX file (simplified parser)
def read_dx(filename):
    """Parse OpenDX file into numpy array"""
    with open(filename) as f:
        lines = f.readlines()
    
    # Find grid dimensions
    for line in lines:
        if line.startswith('object 1 class gridpositions counts'):
            dims = [int(x) for x in line.split()[-3:]]
            break
    
    # Read data
    data_started = False
    data = []
    for line in lines:
        if line.startswith('object 3 class array'):
            data_started = True
            continue
        if data_started and not line.startswith('attribute'):
            data.extend([float(x) for x in line.split()])
    
    return np.array(data).reshape(dims)

# Load potential
pot = read_dx('OUTPUT/apbs_runs/wt_mspa_oriented_pH7.0_0.15M/pot_Lm.dx')

# Calculate statistics
print(f"Min potential: {pot.min():.2f} kT/e")
print(f"Max potential: {pot.max():.2f} kT/e")
print(f"Mean potential: {pot.mean():.2f} kT/e")
```

### Potential along pore axis

Extract 1D potential profile for translocation energy landscapes:

```python
# After loading potential array
# Assuming pore axis is Z (index 2), centered at grid midpoint

nx, ny, nz = pot.shape
center_x, center_y = nx//2, ny//2

# Extract potential along Z at pore center
profile = pot[center_x, center_y, :]

# Save for plotting
import matplotlib.pyplot as plt
z_coords = np.linspace(-50, 50, nz)  # Adjust to your grid
plt.plot(z_coords, profile)
plt.xlabel('Z position (Å)')
plt.ylabel('Potential (kT/e)')
plt.title('Electrostatic potential along pore axis')
plt.savefig('potential_profile.png')
```

## Tips

**File Size Management:**
- Load `pot_Sm.dx` for high-resolution visualization
- Use `pot_Lm.dx` for quick preview (smaller file)
- Fine grid files can be >300 MB - may be slow to load

**Performance:**
- Start with coarse grid calculations for testing visualization scripts
- Use transparency sparingly (computationally expensive)
- For presentations, render high-quality images rather than interactive sessions

**Color Scales:**
- Adjust range to highlight features of interest
- Symmetric scales (e.g., -5 to +5 kT/e) show positive/negative balance
- Asymmetric scales useful when one charge dominates

**Publication Quality:**
- Use ray tracing for final images (`ray` in PyMOL, `render` in ChimeraX)
- Include scale bar for potential values
- Label key structural features (pore entrance, constriction, etc.)
- Show multiple viewpoints (side view, top-down through pore)

## Further resources

- **PyMOL APBS Tools**: https://pymolwiki.org/index.php/APBS
- **VMD APBS Plugin**: https://www.ks.uiuc.edu/Research/vmd/plugins/apbsrun/
- **Chimera Electrostatics**: https://www.cgl.ucsf.edu/chimera/docs/ContributedSoftware/apbs/apbs.html
- **OpenDX Format**: http://opendx.sdsc.edu/docs/html/pages/usrgu068.htm
