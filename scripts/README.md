# Workflow Scripts

This directory contains automation scripts for nanopore simulation workflows. Scripts are organized by workflow type and designed to be called from `justfile` recipes in example directories.

## Directory structure

```
scripts/
├── electrostatics/       # Electrostatics calculation workflows
│   ├── workflow_helpers.sh   # Shared helper functions
│   ├── run_pdb2pqr.sh       # PQR file generation
│   ├── run_apbs.sh          # APBS execution orchestration
│   └── validate_output.sh   # Output validation
└── logs/                 # Script execution logs (gitignored)
```

## Workflow types

### Electrostatics

Scripts for automated APBS (Adaptive Poisson-Boltzmann Solver) electrostatics calculations on membrane proteins. See `electrostatics/README.md` for detailed documentation.

**Key scripts:**
- `run_pdb2pqr.sh` - Batch protonation at multiple pH values
- `run_apbs.sh` - APBS execution with membrane modeling
- `validate_output.sh` - Check calculation completeness and success
- `workflow_helpers.sh` - Shared functions for configuration, templating, and validation

## Usage pattern

Scripts are typically invoked via `just` recipes in example directories:

```bash
cd examples/apbs_mspa/
just pqrs     # Calls scripts/electrostatics/run_pdb2pqr.sh
just apbs     # Calls scripts/electrostatics/run_apbs.sh
just validate # Calls scripts/electrostatics/validate_output.sh
```

Scripts can also be called directly with appropriate arguments:

```bash
# Example: Generate PQR files for specific pH values
./scripts/electrostatics/run_pdb2pqr.sh \
  -i examples/apbs_mspa/pdb/ \
  -o OUTPUT/pqr/ \
  -p "7.0 7.4" \
  -v
```

See individual script help (`-h` flag) for detailed usage information.

## Configuration

Scripts source configuration from `params.env` files in example directories using helper functions from `workflow_helpers.sh`. This allows:
- Centralized parameter management
- Easy customization per workflow
- Parameter override via command-line arguments

## Extension

To add new workflow types:
1. Create a new subdirectory (e.g., `scripts/mutagenesis/`)
2. Implement workflow-specific scripts following the `electrostatics/` pattern
3. Reuse helper functions from existing scripts where applicable
4. Document script APIs in a `README.md` within the subdirectory

See `CONTRIBUTING.md` in the repository root for detailed guidance on extending workflows.