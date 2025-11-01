# MspA Electrostatics Workflow

Automated APBS (Adaptive Poisson-Boltzmann Solver) electrostatics calculations for Mycobacterium smegmatis porin A (MspA) nanopore with lipid membrane modeling.

## Overview

This example demonstrates the complete electrostatics workflow for a biological nanopore:

1. **PQR generation** - Protonate MspA structures at specified pH values
2. **Input preparation** - Create APBS run directories with membrane parameters
3. **APBS calculations** - Compute electrostatic potentials with membrane insertion

The workflow processes multiple PDB MspA variants (wild-type and several D118R
mutants created with different tools), generating electrostatic potential maps
useful for visualizing the electrostatic impact of mutations and conformational
variations.

## Quick start

```bash
# Run complete workflow with default parameters
just all

# Or run stages individually
just pqrs      # Generate PQR files
just inputs    # Prepare APBS input directories
just apbs      # Execute APBS calculations
just validate  # Check outputs are complete and correct
```

Default configuration processes MspA at pH 7.0 with 0.15 M ionic strength using coarse grids suitable for rapid testing.

## Workflow stages

### Stage 1: PQR generation (`just pqrs`)

Converts PDB structures to PQR format with protonation states calculated at specified pH values.

**Input:**
- PDB files in `pdb/` directory
- Custom CHARMM force field in `pdb2pqr_forcefield/`

**Output:**
- `OUTPUT/pqr/{protein}_pH{pH}.pqr` - Protonated structures with atomic charges and radii
- Log files for troubleshooting protonation issues

**Customization:**
```bash
# Single pH value
just PH_VALUES="7.4" pqrs

# Multiple pH values
just PH_VALUES="6.0 7.0 8.0" pqrs
```

### Stage 2: input preparation (`just inputs`)

Creates APBS run directories with templated input files for each PQR × ion concentration combination.

**Input:**
- PQR files from Stage 1
- Templates in `apbs_templates/`
- Configuration from `params.env`

**Output (per combination):**
- `OUTPUT/apbs_runs/{protein}_pH{pH}_{ionc}M/`
  - `apbs_dummy.in` - Dummy run configuration (generates coefficient maps)
  - `apbs_solv.in` - Solvation run configuration (calculates potentials)
  - `draw_membrane.in` - Membrane geometry parameters
  - `TM.pqr` - Symlinked structure file

**Customization:**
```bash
# Single ion concentration
just IONC_VALUES="0.10" inputs

# Multiple concentrations
just IONC_VALUES="0.05 0.10 0.15 0.20" inputs
```

### Stage 3: APBS execution (`just apbs`)

Runs APBS calculations with membrane insertion for each prepared directory.

**Workflow per directory:**
1. **Dummy run** - APBS generates dielectric, ion accessibility, and charge distribution maps
2. **Membrane insertion** - `draw_membrane2` modifies maps to include lipid bilayer boundaries
3. **Solvation run** - APBS calculates electrostatic potentials using membrane-modified maps

**Output (per run directory):**
- Coefficient maps (before membrane):
  - `dielx_L.dx`, `diely_L.dx`, `dielz_L.dx` - Dielectric constants
  - `kappa_L.dx` - Ion accessibility
  - `charge_L.dx` - Charge distribution

- Coefficient maps (after membrane, `*_Lm.dx` suffix):
  - `dielx_Lm.dx`, `diely_Lm.dx`, `dielz_Lm.dx`
  - `kappa_Lm.dx`
  - `charge_Lm.dx`

- Electrostatic potentials:
  - `pot_Lm.dx` - Potential on coarse grid
  - `pot_Sm.dx` - Potential on fine grid (if different from coarse)

- Logs:
  - `apbs_dummy.out` - Dummy run output
  - `apbs_solv.out` - Solvation run output with energy values

**Energy calculations:**
Check `.out` files for lines like:
```
Total electrostatic energy = -1.234567E+03 kJ/mol
```

### Validation (`just validate`)

Verifies calculation completeness and success by checking:
- All expected `.dx` files exist
- `.out` files contain "Total electrostatic energy" markers
- No failed or incomplete calculations

### Output validation and file structure

For default configuration (`PH_VALUES="7.0"`, `IONC_VALUES="0.15"`, 4 PDB files):

**PQR generation:**
- 4 PQR files (one per PDB file at pH 7.0)
- 4 log files

**APBS runs:**
- 4 run directories (4 PDB files × 1 pH × 1 ionc)
- Each directory contains 21 files:
  - 3 input files (`.in`)
  - 1 PQR symlink
  - 11 coefficient maps (`.dx` before and after membrane)
  - 2 potential maps (`.dx`)
  - 2 output logs (`.out`)
  - 1 temporary file (`io.mc`)

**Total:** 4 PQR directories + 84 files in APBS run directories = ~88 files

**Full parameter sweep example:**

For `PH_VALUES="6.0 7.0 8.0"` and `IONC_VALUES="0.05 0.10 0.15 0.20"`:
- **PQR files:** 4 PDB × 3 pH = 12 PQR files + 12 logs
- **APBS run directories:** 4 PDB × 3 pH × 4 ionc = 48 directories
- **Total files:** 24 (PQR) + (48 × 21) = 1,032 files

**Critical files for validation:**

Per PDB file:
- `OUTPUT/pqr/{protein}_pH{pH}.pqr` - Protonated structure

Per run directory:
- `TM.pqr` - Structure file (symlink should not be broken)
- `pot_Lm.dx` - Coarse grid electrostatic potential (primary result)
- `pot_Sm.dx` - Fine grid electrostatic potential (if using focused calculation)
- `apbs_solv.out` - Solvation run log (contains energy values)

**Success indicators in log files:**

APBS logs (`apbs_solv.out`) should contain:
```
Total electrostatic energy = -X.XXXXXXE+XX kJ/mol
```
Absence of this line indicates calculation failure.

**Manual validation commands:**

```bash
# Count PQR files (should equal: # PDB files × # pH values)
find OUTPUT/pqr/ -name "*.pqr" | wc -l

# Count run directories (should equal: # PDB files × # pH values × # ionc values)
find OUTPUT/apbs_runs/ -mindepth 1 -maxdepth 1 -type d | wc -l

# Check for critical output files
find OUTPUT/apbs_runs/ -name "pot_Lm.dx" | wc -l

# Check for successful APBS completions
grep -r "Total electrostatic energy" OUTPUT/apbs_runs/*/apbs_solv.out | wc -l
```

**Disk space planning:**

Estimate required disk space before running:
```
Space = (# PDB files) × (# pH values) × (# ionc values) × (size per run dir)

Coarse grid:  4 × 3 × 4 × 25 MB  = ~1.2 GB
Fine grid:    4 × 3 × 4 × 6 GB   = ~288 GB
```

**Typical file sizes (coarse grid: `DIME=65 65 65`):**
- PQR files: 500 KB - 2 MB
- Input files (`.in`): ~1-2 KB each
- Coefficient maps (`.dx`): ~1-2 MB each
- Potential maps (`.dx`): ~1-2 MB each
- Log files (`.out`): 10-50 KB
- **Per run directory:** ~20-30 MB

**Fine grid sizes (`DIME=417 417 449`):**
- Coefficient maps (`.dx`): ~300-400 MB each
- Potential maps (`.dx`): ~300-400 MB each
- **Per run directory:** ~5-7 GB

### Cleanup

```bash
just clean     # Remove all OUTPUT/ contents
```

## Configuration

Edit `params.env` to customize workflow parameters.

### pH and ionic strength

```bash
PH_VALUES="7.0"          # Physiological pH
IONC_VALUES="0.15"       # Physiological ionic strength (M)
```

### Grid settings

APBS uses multigrid methods requiring specific dimension formulas:
```
dime = c × 2^(nlev+1) + 1
```
where `c` and `nlev` are positive integers.

**Common valid dimensions:**
33, 65, 97, 129, 161, 193, 225, 257, 289, 321, 353, 385, 417, 449, 481, 513, ...

**Current settings (coarse grid - fast):**
```bash
GCENT="0 0 30"           # Grid center (x, y, z) in Å
GRID_L="15 15 15"        # Coarse grid spacing in Å
GRID_S="5 5 5"           # Fine grid spacing in Å
DIME_L="65 65 65"        # Coarse grid dimensions
DIME_S="65 65 65"        # Fine grid dimensions (same for single-focus)
```

**Fine grid configuration (commented in params.env - slower, more accurate):**
```bash
GRID_L="2.0 2.0 2.0"     # Finer coarse grid
GRID_S="0.5 0.5 0.5"     # Very fine grid
DIME_L="417 417 449"     # Larger dimensions
DIME_S="417 417 449"
```

**Grid tuning guidance:**
- Increase `DIME` if you see "Atom off the mesh" errors
- Decrease `GRID` spacing for higher resolution (increases computation time)
- Adjust `GCENT` to center grid on region of interest
- Ensure all protein atoms within grid boundaries

### Membrane parameters

```bash
ZMEM=-18        # Membrane center z-coordinate (Å)
LMEM=36         # Membrane thickness (Å)
R_TOP=23.2      # Top exclusion radius (Å)
R_BOTTOM=17.5   # Bottom exclusion radius (Å)
```

**Physical interpretation:**
- `ZMEM`: Vertical position of bilayer center (coordinate system dependent)
- `LMEM`: Typical lipid bilayer thickness ~30-40 Å
- `R_TOP/R_BOTTOM`: Define membrane shape (cylindrical exclusion zones)
- These values are MspA-specific; adjust for other nanopores

**Dielectric constants:**
```bash
PDIE=10.0       # Protein interior dielectric
SDIE=80.0       # Water/solvent dielectric
```

Membrane dielectric is fixed at 2.0 inside `draw_membrane2.c` (not configurable in `params.env`).

### Advanced settings

```bash
IONR=2.0        # Ion radius in Å (affects ion accessibility)
MEMV=0.0        # Membrane potential offset (V), not used here
```

## Understanding outputs

### PQR files

PQR format extends PDB with atomic charges and radii:
```
ATOM      1  N   MET A   1      -10.123   5.456  12.789  0.350  1.850
#         ^  ^   ^^^ ^ ^^^      ^^^^^^^ ^^^^^^^ ^^^^^^^  ^^^^^  ^^^^^
#      Index Name Res ChainRes      X       Y       Z   Charge Radius
```

Use for visualization or further analysis with electrostatics-aware tools.

### Electrostatic potential maps (.dx files)

OpenDX format grid data. Load into visualization software:
- **PyMOL**: See `VISUALIZATION.md`
- **VMD**: See `VISUALIZATION.md`
- **Chimera/ChimeraX**: See `VISUALIZATION.md`

**Key files:**
- `pot_Lm.dx` - Coarse grid potential with membrane
- `pot_Sm.dx` - Fine grid potential with membrane (if using focusing)

**Typical usage:**
- Visualize electrostatic surfaces (isocontours)
- Calculate potential along translocation paths
- Compare potentials at different pH/ionic strengths

### Energy values

APBS writes total electrostatic energy near the end of `apbs_solv.out`:
```
Total electrostatic energy = -1.234567E+03 kJ/mol
```
This line is the success marker used by `just validate`.

**How to extract energies for all runs:**
```bash
grep -h "Total electrostatic energy" OUTPUT/apbs_runs/*/apbs_solv.out
```

**Quick summary (count successful runs):**
```bash
grep -r "Total electrostatic energy" OUTPUT/apbs_runs/*/apbs_solv.out | wc -l
```

**Interpretation guidelines:**
- Units: kJ/mol (APBS reports energies in consistent units; convert as needed).
- More negative values generally indicate stronger favorable electrostatic interactions under the modeled conditions.
- Compare across pH or ionic strength sweeps to identify conditions that stabilize (large negative shift) or destabilize (less negative / positive shift) the pore environment.
- Large deviations between similar conditions may indicate grid mis-centering or an incomplete run—revalidate those directories.

**Failure indicators:**
- Missing energy line entirely.
- Presence of error strings ("ASSERTION FAILURE", "Atom off the mesh").
- Zero-length or absent potential/map files.

If any failure indicators appear, adjust grid (`DIME_*`, `GRID_*`) or membrane geometry (`ZMEM`, `LMEM`, radii) and re-run affected directories.

### Parameter sweeps

To explore multiple pH or ionic strengths, edit `params.env`:
```bash
PH_VALUES="6.0 7.0 8.0"
IONC_VALUES="0.05 0.10 0.15 0.20"
```
Then re-run:
```bash
just clean && just all
```

After completion, summarize energies:
```bash
for f in OUTPUT/apbs_runs/*/apbs_solv.out; do
  printf "%s\t" "$(basename "$(dirname "$f") )"""
  grep -h "Total electrostatic energy" "$f"
done | column -t
```

You can subset by condition:
```bash
grep -r "Total electrostatic energy" OUTPUT/apbs_runs/*pH6.0*/*/apbs_solv.out
```

For disk usage planning in large sweeps, see the earlier "Disk space planning" section.

## Troubleshooting

See the main [README.md troubleshooting section](../../README.md#troubleshooting) for common issues and solutions.

**MspA-specific issues:**

**Membrane parameters not appropriate:**
- Adjust `ZMEM`, `LMEM`, `R_TOP`, `R_BOTTOM` in `params.env`
- These values are protein-specific; MspA defaults may not work for other nanopores

**Grid center misalignment:**
- Verify `GCENT` centers grid on pore region
- Use visualization software to check protein coordinates
- MspA pore axis should align with Z-axis

**Custom force field issues:**
- Try running without custom force field (remove `--userff` flag from `run_pdb2pqr.sh`)
- Check `pdb2pqr_forcefield/` files for errors
- Review PDB2PQR log files for force field warnings

## Further reading

- APBS documentation: https://www.poissonboltzmann.org/
- PDB2PQR documentation: https://pdb2pqr.readthedocs.io/
- Poisson-Boltzmann theory: https://en.wikipedia.org/wiki/Poisson%E2%80%93Boltzmann_equation
- MspA structure: PDB ID 1UUN (https://www.rcsb.org/structure/1uun)