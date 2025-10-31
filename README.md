# Nanopore Simulation Tools

Automated workflow tools for running electrostatic calculations on biological nanopore membrane proteins using APBS (Adaptive Poisson-Boltzmann Solver). This toolkit demonstrates reproducible computational workflows for nanopore biophysics research.

**Key Features:**
- Automated three-stage pipeline: PDB → PDB2PQR → APBS (with membrane modeling)
- Parameter sweep capabilities (pH, ionic strength, grid resolutions)
- Template-based configuration system
- Custom CHARMM force fields for specialized residues
- Built-in validation and error recovery

## Quick start

```bash
# 1. Clone repository
git clone https://github.com/willemsk/nanopore-simulation-tools.git
cd nanopore-simulation-tools

# 2. Set up conda environment
conda env create -f environment.yml
conda activate nanopore-sim

# 3. Install APBS and just (see Installation section below)

# 4. Run example workflow
cd examples/apbs_mspa
just all
```

This will generate protonated structures (`.pqr` files) and electrostatic potential maps (`.dx` files) for the MSpA nanopore at multiple pH values and ionic strengths.

## Installation

### Prerequisites

This toolkit requires three main dependencies:

1. **Python environment (conda recommended)**
   ```bash
   conda env create -f environment.yml
   conda activate nanopore-sim
   ```
   This installs Python ≥3.8, PDB2PQR, and NumPy.

2. **APBS (Adaptive Poisson-Boltzmann Solver)**
   
   Build from source for best compatibility:
   ```bash
   # Install dependencies (Ubuntu/Debian)
   sudo apt-get install cmake build-essential gfortran
   
   # Clone and build APBS
   git clone https://github.com/Electrostatics/apbs.git
   cd apbs
   mkdir build && cd build
   cmake -DENABLE_OPENMP=ON ..
   make -j4
   sudo make install
   ```
   
   **Alternative:** Pre-compiled Intel binaries are provided in `bin/` as a convenience option (see `bin/README.md`).

3. **just (command runner)**
   ```bash
   # macOS
   brew install just
   
   # Linux (cargo)
   cargo install just
   
   # Or download binary from https://github.com/casey/just/releases
   ```

4. **draw_membrane2 utility** (for membrane modeling)
   
   Compile from APBS examples:
   ```bash
   cd bin/
   # If not already compiled, get source from APBS examples
   wget https://raw.githubusercontent.com/Electrostatics/apbs/main/examples/helix/draw_membrane2.c
   gcc -O3 -o draw_membrane2 draw_membrane2.c -lm
   ```

### Verification

After installation, verify dependencies:

```bash
pdb2pqr30 --version    # Should show PDB2PQR version
apbs --version          # Should show APBS version
just --version          # Should show just version
./bin/draw_membrane2    # Should show usage message
```

## Usage

### Basic workflow

Navigate to an example directory and run the automated pipeline:

```bash
cd examples/apbs_mspa
just all               # Run complete workflow
```

This executes three stages:
1. **PQR generation** (`just pqrs`) - Protonate structures at specified pH values
2. **Input preparation** (`just inputs`) - Create APBS run directories with templated inputs
3. **APBS calculations** (`just apbs`) - Execute electrostatics calculations with membrane

### Customizing parameters

Edit `params.env` to configure:
- **pH values**: `PH_VALUES="6.0 7.0 8.0"`
- **Ionic strength**: `IONC_VALUES="0.05 0.10 0.15"`
- **Grid settings**: `DIME_L`, `GRID_L` for coarse grid; `DIME_S`, `GRID_S` for fine grid
- **Membrane geometry**: `ZMEM` (center), `LMEM` (thickness), `R_TOP`/`R_BOTTOM` (radii)

Override from command line:
```bash
just pqrs PH_VALUES="7.4"              # Single pH
just inputs IONC_VALUES="0.10 0.20"    # Custom ion concentrations
```

### Validation and recovery

Check that outputs are complete and correct:
```bash
just validate          # Verify all expected files exist and calculations succeeded
```

Resume incomplete calculations:
```bash
just resume            # Re-run only missing or failed calculations
```

### Output structure

Successful runs produce:
```
OUTPUT/
├── pqr/
│   └── {protein}_pH{pH}.pqr                    # Protonated structures
└── apbs_runs/
    └── {protein}_pH{pH}_{ionc}M/
        ├── apbs_dummy.in, apbs_solv.in         # APBS input files
        ├── draw_membrane.in                     # Membrane parameters
        ├── TM.pqr                               # Symlinked structure
        ├── dielx_L.dx, dielx_Lm.dx             # Dielectric maps (before/after membrane)
        ├── kappa_L.dx, kappa_Lm.dx             # Ion accessibility maps
        ├── charge_L.dx, charge_Lm.dx           # Charge distribution maps
        ├── pot_Lm.dx, pot_Sm.dx                # Electrostatic potentials (coarse/fine)
        └── apbs_*.out                           # APBS output logs
```

See `examples/apbs_mspa/EXPECTED_OUTPUT.md` for complete file listing.

### Cleaning up

```bash
just clean             # Remove all generated outputs
```

## Project structure

```
nanopore-simulation-tools/
├── bin/                      # Pre-compiled binaries (convenience)
│   ├── apbs-intel           # Intel-compiled APBS
│   └── draw_membrane2       # Membrane modeling utility
├── scripts/
│   └── electrostatics/      # Bash workflow scripts
│       ├── workflow_helpers.sh   # Shared helper functions
│       ├── run_pdb2pqr.sh       # PQR generation script
│       ├── run_apbs.sh          # APBS orchestration script
│       └── validate_output.sh   # Output validation script
└── examples/
    └── apbs_mspa/           # MSpA electrostatics workflow
        ├── justfile         # Workflow orchestration recipes
        ├── params.env       # Configuration parameters
        ├── apbs_templates/  # APBS input templates
        ├── pdb/             # Input PDB structures
        └── pdb2pqr_forcefield/  # Custom CHARMM force fields
```

## Troubleshooting

### Common issues

**"APBS binary not found"**
- Ensure APBS is in your PATH or update `APBS_BIN` in the justfile
- Try using pre-compiled binary: check `bin/README.md`

**"Atom off the mesh" errors**
- Increase grid size: edit `GRID_L` and/or `GRID_S` in `params.env`
- Verify grid center `GCENT` encompasses your protein

**Invalid grid dimensions**
- APBS requires: `dime = 2 × c^(nlev+1) + 1` for some integers c and nlev
- Use provided values in `params.env` or calculate new ones following this formula
- `just validate` checks this automatically before running

**PDB2PQR protonation failures**
- Check for missing atoms or non-standard residues in PDB file
- Review `.log` files in `OUTPUT/pqr/` for detailed error messages
- Consider using standard CHARMM force field instead of custom if issues persist

**Silent calculation failures**
- Run `just validate` to check output completeness
- Inspect `.out` files in run directories for APBS error messages
- Look for "Global net ELEC energy" in `.out` files - absence indicates failure

### Getting help

For additional assistance:
1. Check detailed workflow documentation in `examples/apbs_mspa/README.md`
2. Review APBS documentation: https://www.poissonboltzmann.org/
3. Review PDB2PQR documentation: https://pdb2pqr.readthedocs.io/
4. Open an issue on GitHub: https://github.com/willemsk/nanopore-simulation-tools/issues

## Citation

If you use this toolkit in your research, please cite:

```bibtex
@software{nanopore_simulation_tools,
  author = {Willems, Kherim},
  title = {Nanopore Simulation Tools},
  year = {2025},
  url = {https://github.com/willemsk/nanopore-simulation-tools}
}
```

And cite the underlying tools (see `CITATION.cff` for complete references):
- **APBS**: https://www.poissonboltzmann.org/
- **PDB2PQR**: https://pdb2pqr.readthedocs.io/

## License

This project is licensed under the BSD 3-Clause License - see the `LICENSE` file for details.

## Contributing

We welcome contributions! See `CONTRIBUTING.md` for guidelines on:
- Reporting issues
- Adapting workflows for new proteins
- Creating custom force fields
- Adding new workflow types

## Acknowledgments

This toolkit was developed to support computational biophysics research on biological nanopores. It integrates and automates workflows using APBS, PDB2PQR, and the draw_membrane2 utility from the APBS examples.
