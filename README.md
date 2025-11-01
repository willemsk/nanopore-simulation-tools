# Nanopore simulation tools

Automated workflow tools for running electrostatic calculations on biological
nanopore membrane proteins using
[PDB2PQR](https://github.com/Electrostatics/pdb2pqr) and
[APBS](https://github.com/Electrostatics/apbs). This toolkit is very much a work
in progress and aims to provide examples of reproducible computational workflows
to aid in nanopore biophysics research.

**Warning:** This is an early-stage project under active development. Use at your
own risk. We are still looking for the optimal implementation of the workflows,
so any feedback and contributions are welcome!

## Key features

- Automated three-stage pipeline: PDB → PDB2PQR → APBS (with membrane modeling)
- Parameter sweep capabilities (pH, ionic strength, grid resolutions)

## Quick start

Assuming an Ubuntu system with `git`, `gcc`, and `bash` installed, follow these steps
to set up and run the example workflow:

```bash
# 1. Clone repository
git clone https://github.com/willemsk/nanopore-simulation-tools.git
cd nanopore-simulation-tools

# 2. Install dependencies
sudo apt-get install just pdb2pqr apbs

# 3. Fetch and compile draw_membrane2 utility
cd bin/
wget https://raw.githubusercontent.com/Electrostatics/apbs/main/examples/helix/draw_membrane2.c
gcc -O3 -o draw_membrane2 draw_membrane2.c -lm
cd ..

# 4. Run example workflow
cd examples/apbs_mspa
just all
```

This will generate protonated structures (`.pqr` files) and electrostatic
potential maps (`.dx` files) for several MspA-D118R mutant nanopores at pH 7.0
and and ionic strength of 0.15 M. Note that the default grid spacings are set to
very coarse values (15 Å and 5 Å) for demonstration purposes and should need to
be increased for production runs. Mind that the memory and disk space
requirements grow with $n^3$ as the number of grid points $n$ per dimension
increases.

## Installation

### Prerequisites

This toolkit requires these main dependencies:

- **`just` (command runner):** see [installation guide](https://github.com/casey/just?tab=readme-ov-file#installation)
- **`PDB2PQR` (structure protonation tool):** see [installation guide](https://pdb2pqr.readthedocs.io/en/latest/getting.html#python-package-installer-pip)
- **`APBS` (electrostatics solver):** see [installation guide](https://apbs.readthedocs.io/en/latest/getting/index.html#installing-from-pre-compiled-binaries) or [build from source](https://apbs.readthedocs.io/en/latest/getting/source.html)
- **`draw_membrane2` (membrane drawing utility):** compile from [APBS `helix` example](https://github.com/Electrostatics/apbs/tree/main/examples/helix/draw_membrane2.c) (see above)

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
just PH_VALUES="7.4" pqrs              # Single pH
just IONC_VALUES="0.10 0.20" inputs    # Custom ion concentrations
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
        ├── draw_membrane.in                    # Membrane parameters
        ├── TM.pqr                              # Symlinked structure
        ├── dielx_L.dx, dielx_Lm.dx             # Dielectric maps (before/after membrane)
        ├── kappa_L.dx, kappa_Lm.dx             # Ion accessibility maps
        ├── charge_L.dx, charge_Lm.dx           # Charge distribution maps
        ├── pot_Lm.dx, pot_Sm.dx                # Electrostatic potentials (coarse/fine)
        └── apbs_*.out                          # APBS output logs
```

See [`examples/apbs_mspa/README.md`](examples/apbs_mspa/README.md) for complete
output structure and validation details.

### Cleaning up

```bash
just clean             # Remove all generated outputs
```

## Project structure

```
nanopore-simulation-tools/
├── bin/                         # Compiled binaries
├── scripts/
│   └── electrostatics/          # Electrostatics workflow automation
│       ├── workflow_helpers.sh  # Shared helper functions
│       ├── run_pdb2pqr.sh       # PQR generation script
│       ├── run_apbs.sh          # APBS orchestration script
│       └── validate_output.sh   # Output validation script
└── examples/
    └── apbs_mspa/               # MspA electrostatics workflow
        ├── justfile             # Workflow orchestration recipes
        ├── params.env           # Configuration parameters
        ├── apbs_templates/      # APBS input templates
        ├── pdb/                 # Input PDB structures
        └── pdb2pqr_forcefield/  # Custom CHARMM force fields
```

### Workflow scripts

Scripts in [`scripts/electrostatics/`](scripts/electrostatics/) automate the
three-stage pipeline and are typically invoked via `just` recipes:

```bash
cd examples/apbs_mspa/
just pqrs     # Creates .pqr files from input PDBs target pH  value(s)
just inputs   # Prepares APBS input directories
just apbs     # Executes all APBS calculations
just validate # Validates output completeness of APBS runs
```

Scripts can in principe also be called directly with command-line arguments. See
individual script help (`-h` flag) for usage information. All scripts source
configuration from `params.env` files in example directories.

## Troubleshooting

### Common issues

**"APBS binary not found"**
- Ensure APBS is installed and available in your PATH
- Verify with `which apbs` or `apbs --version`
- See [APBS installation guide](https://apbs.readthedocs.io/en/latest/getting/index.html)

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
- Look for "Total electrostatic energy" in `.out` files - absence indicates failure

### Getting help

For additional assistance:
1. Check detailed workflow documentation in `examples/apbs_mspa/README.md`
2. Review [APBS documentation](https://apbs.readthedocs.io/)
3. Review [PDB2PQR documentation](https://pdb2pqr.readthedocs.io/)
4. Open an [issue on GitHub](https://github.com/willemsk/nanopore-simulation-tools/issues)

## Citation

If you use this toolkit in your research, please cite (see [`CITATION.cff`](CITATION.cff) for complete references):

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

## Contributors

**Main contributors:**
- Kherim Willems
- Francesco Quilli
- Mauro Chinappi

**Other contributors:**
- Marco Reccia
- Blasco Morozzo della Rocca
- Domenico Raimondo

## Contributing

We welcome contributions! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines on:
- Reporting issues
- Adapting workflows for new proteins
- Creating custom force fields
- Adding new workflow types

## License

This project is licensed under the GNU GPL v3. See the [`LICENSE`](LICENSE) file for details.

## Acknowledgments

This project builds upon and integrates several open-source tools:

- **APBS** and `draw_membrane2` utility: Electrostatics calculations, including membrane environment
- **PDB2PQR**: Structure preparation and protonation state assignment
- **just**: Workflow orchestration and task management

It is a work in progress, so any feedback is appreciated!
