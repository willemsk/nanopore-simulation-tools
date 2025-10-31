# Nanopore Simulation Tools

Automated workflow tools for running electrostatic calculations on biological nanopore membrane proteins using APBS (Adaptive Poisson-Boltzmann Solver). This toolkit demonstrates reproducible computational workflows for nanopore biophysics research.

**Key Features:**
- Automated three-stage pipeline: PDB → PDB2PQR → APBS (with membrane modeling)
- Parameter sweep capabilities (pH, ionic strength, grid resolutions)
- Template-based configuration system
- Custom CHARMM force fields for specialized residues
- Built-in validation and error recovery

## Quick start

Assuming an Ubuntu system with `git` and `bash` installed, follow these steps
to set up and run the example workflow:

```bash
# 1. Clone repository
git clone https://github.com/willemsk/nanopore-simulation-tools.git
cd nanopore-simulation-tools

# 2. Install dependencies
sudo apt-get install just pdb2pqr apbs

# 3. Run example workflow
cd examples/apbs_mspa
just all
```

This will generate protonated structures (`.pqr` files) and electrostatic potential maps (`.dx` files) for the MSpA nanopore at multiple pH values and ionic strengths.

## Installation

### Prerequisites

This toolkit requires three main dependencies:

1. **`just` (command runner):** see [installation guide](https://github.com/casey/just?tab=readme-ov-file#installation)
3. **`PDB2PQR` (structure protonation tool):** see [installation guide](https://pdb2pqr.readthedocs.io/en/latest/getting.html#python-package-installer-pip)
4. **`APBS` (electrostatics solver):** see [installation guide](https://apbs.readthedocs.io/en/latest/getting/index.html#installing-from-pre-compiled-binaries)
5. **`draw_membrane2` (membrane drawing utility):** see [`helix` example](https://github.com/Electrostatics/apbs/tree/main/examples/helix)
   It should already be in the `bin/` directory, but can also be compiled from source:
   ```bash
   cd bin/
   # If not already compiled, get source from APBS examples
   wget https://raw.githubusercontent.com/Electrostatics/apbs/main/examples/helix/draw_membrane2.c
   gcc -O3 -o draw_membrane2 draw_membrane2.c -lm
   ```

### Verification

After installation, verify dependencies:

```bash
just --version          # Should show just version
pdb2pqr30 --version     # Should show PDB2PQR version
apbs --version          # Should show APBS version
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
- APBS requires: `dime = c × 2^(nlev+1) + 1` for some integers `c` and `nlev` (see [`dime` documentation](https://apbs.readthedocs.io/en/latest/using/input/old/elec/dime.html?highlight=dime#dime))
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
2. Review [APBS documentation](https://apbs.readthedocs.io/)
3. Review [PDB2PQR documentation](https://pdb2pqr.readthedocs.io/)
4. Open an [issue on GitHub](https://github.com/willemsk/nanopore-simulation-tools/issues)

## Citation

If you use this toolkit in your research, please cite (see `CITATION.cff` for complete references):

```bibtex
@software{nanopore_simulation_tools,
  author = {Reccia, Marco and Quilli, Francesco and Willems, Kherim and Morozzo della Rocca, Blasco and Raimondo, Domenico and Chinappi, Mauro},
  title = {Bioinformatic and computational biophysics tools for nanopore engineering: a review from standard approaches to machine learning advancements},
  year = {2025},
  journal = {Journal of Nanobiotechnology},
  url = {https://github.com/willemsk/nanopore-simulation-tools}
}
```

And cite the underlying tools:
- **APBS**: see [citing APBS](https://apbs.readthedocs.io/en/latest/supporting.html#citing-our-software)
- **PDB2PQR**: see [citing PDB2PQR](https://pdb2pqr.readthedocs.io/en/latest/supporting.html#citing-our-software)

## License

This project is licensed under the BSD 3-Clause License - see the `LICENSE` file for details.

## Contributing

We welcome contributions! See `CONTRIBUTING.md` for guidelines on:
- Reporting issues
- Adapting workflows for new proteins
- Creating custom force fields
- Adding new workflow types

## Acknowledgments

This toolkit was developed to support computational biophysics research on
biological nanopores. It integrates and automates workflows using `APBS`,
`PDB2PQR`, and the `draw_membrane2` utility from the `APBS` examples. It is a
work in progress, so any feedback is appreciated!
