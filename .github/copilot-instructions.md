# Nanopore simulation tools - AI agent instructions

## Project overview

This is a computational biophysics toolkit for running APBS (Adaptive Poisson-Boltzmann Solver) electrostatics calculations on nanopore membrane proteins. The current focus is electrostatics, with planned expansion to mutagenesis, particle translocation energy landscapes, and pore diameter calculations.

**Key workflow**: PDB → PDB2PQR (protonation) → APBS dummy run (coefficient maps) → draw_membrane2 (add membrane) → APBS calculation (electrostatics)

## Architecture

### Directory structure
- `bin/` - Pre-compiled Intel binaries: `apbs-intel` (APBS solver), `draw_membrane2` (membrane modeler from [APBS examples](https://github.com/Electrostatics/apbs/blob/main/examples/helix/draw_membrane2.c))
- `scripts/electrostatics/` - Bash orchestration scripts and helper functions
- `examples/` - Workflow templates (currently `apbs_mspa/` demonstrates electrostatics pipeline)
  - Each example is self-contained with `justfile`, `params.env`, templates, and force fields

### Workflow components

1. **Configuration**: `params.env` files define simulation parameters (pH, ionic strength, grid settings, membrane geometry)
2. **Templates**: `apbs_templates/*.in` contain placeholder-based APBS input files (e.g., `GCENT`, `IONC`, `PDIE`)
3. **Force Fields**: Custom CHARMM force field definitions in `pdb2pqr_forcefield/` (`.dat`, `.names`, `.str`)
4. **Orchestration**: `justfile` recipes chain the three stages with dependency checking

## Critical conventions

### Just-based workflow management

All workflows use `just` (not make). Key recipes in `examples/apbs_mspa/justfile`:
- `just pqrs` - Generate PQR files at specified pH values
- `just inputs` - Prepare APBS run directories with templated inputs
- `just apbs` - Execute APBS calculations across all configurations
- `just all` - Run full pipeline sequentially

Override parameters: `just pqrs PH_VALUES="7.0 7.4"` or `just inputs IONC_VALUES="0.10 0.15"`

### Configuration pattern

`params.env` uses simple `KEY=value` format (no exports, no shell functions):
- Space-separated arrays: `IONC_VALUES="0.10 0.15"`
- Template paths: `APBS_DUMMY_TEMPLATE=apbs_templates/apbs_dummy-TEMPLATE.in`
- Grid settings must follow APBS constraints: `dime = 2*c^(nlev+1) + 1` for multigrid

Loaded by `justfile` via `set dotenv-load := true` and by bash scripts via `workflow_helpers.sh::get_config_value()`

### Template substitution

Helper functions in `workflow_helpers.sh` perform sed-based replacement:
- `create_apbs_input template.in output.in ionc` - Substitutes placeholders like `GCENT`, `DIME_L`, `IONC`
- `create_draw_input output.file ionc` - Writes membrane parameters as space-separated values

Required placeholders in APBS templates: `GCENT`, `DIME_L`, `DIME_S`, `GRID_L`, `GRID_S`, `PDIE`, `SDIE`, `IONC`, `IONR`

### Shell script patterns

Bash scripts follow strict conventions:
- `set -e` for immediate exit on error
- Verbose output controlled by `-v` flag: `printf_verbose "message"` only prints if enabled
- Working directory changes wrapped in subshells: `(cd $dir && command)`
- Input validation before execution (see `check_pdb_files`, `check_pqr_files` in `workflow_helpers.sh`)

### APBS execution model

Two-stage APBS runs per configuration:
1. **Dummy run** (`mg-dummy` mode): Generates coefficient maps (diel, kappa, charge) without membrane
2. **Draw membrane**: Modifies `.dx` maps using `draw_membrane2` with parameters from `draw_membrane.in`
3. **Production run** (`mg-manual` mode): Uses modified maps to calculate electrostatic potential

Output naming: `{protein}_pH{pH}_{ionc}M/` directories contain `apbs_dummy.in`, `apbs_solv.in`, `TM.pqr`, and results

## Developer workflows

### Running a simulation

```bash
cd examples/apbs_mspa
# Edit params.env to configure pH, ion concentration, grid settings
just all                    # Full pipeline
just clean && just all      # Clean rebuild
```

### Adding new parameters

1. Add to `params.env` with clear comments
2. Update `workflow_helpers.sh::create_apbs_input()` for template substitution
3. Add placeholder to template files in `apbs_templates/`
4. Update `validate_templates()` to check for new placeholder

### Custom force fields

PDB2PQR force fields live in `pdb2pqr_forcefield/`:
- `.dat` files define atom parameters (charge, radius, bonds)
- `.names` maps PDB atom names to CHARMM names (XML format with regex patterns)
- Use `--userff` and `--usernames` flags in `run_pdb2pqr.sh`

### System requirements

**Required dependencies:**
- `pdb2pqr30` - Must be available in PATH ([installation guide](https://pdb2pqr.readthedocs.io/))
- `just` - Command runner for workflow orchestration ([installation guide](https://github.com/casey/just))
- Bash 4.0+ with standard utilities (`sed`, `grep`, `find`)

**Binaries in `bin/`:**
- `apbs-intel` - Intel-compiled APBS solver (build from [APBS source](https://github.com/Electrostatics/apbs))
- `draw_membrane2` - Membrane drawing utility (compile from [APBS examples](https://github.com/Electrostatics/apbs/blob/main/examples/helix/draw_membrane2.c))

Justfile resolves binary paths dynamically: `APBS_BIN := realpath ../../bin/apbs-intel`

## Common patterns

### Batch processing across parameters

Scripts iterate over space-separated values from `params.env`:
```bash
for ph in $PH_VALUES; do
  for ionc in $IONC_VALUES; do
    # Generate run directory per combination
  done
done
```

### Error handling in recipes

Justfile recipes source `workflow_helpers.sh` and use dependency checks:
```bash
if ! check_pqr_files '{{PQR_OUTPUT_DIR}}'; then
  echo "Run 'just pqrs' first."
  exit 0  # Soft fail, not error
fi
```

### Output organization

Generated files follow strict hierarchy:
```
OUTPUT/
├── pqr/{protein}_pH{pH}.pqr
└── apbs_runs/{protein}_pH{pH}_{ionc}M/
    ├── apbs_dummy.in, apbs_solv.in, draw_membrane.in
    ├── TM.pqr (symlinked/copied)
    ├── dielx_L.dx, dielx_Lm.dx (pre/post membrane)
    └── pot_Lm.dx, pot_Sm.dx (final potentials)
```

## Important notes

- Grid dimensions (`DIME_L`, `DIME_S`) must satisfy APBS multigrid formula or calculations fail silently
- Membrane drawing modifies `.dx` files in-place, appending `m` suffix to output
- PDB2PQR uses `--whitespace` flag to ensure APBS compatibility
- `VERBOSE=true` in `params.env` enables detailed progress output

## Output validation

### Expected output structure
Each successful APBS run produces:
- `*.pqr` files - Protonated structures with atomic charges/radii
- `dielx_L.dx`, `dielx_Lm.dx` - Dielectric coefficient maps (pre/post membrane)
- `kappa_L.dx`, `kappa_Lm.dx` - Ion accessibility maps
- `charge_L.dx`, `charge_Lm.dx` - Charge distribution maps
- `pot_Lm.dx`, `pot_Sm.dx` - Final electrostatic potential on coarse/fine grids
- `*.out` - APBS output logs containing energy calculations

### Success indicators
Check APBS output logs (`.out` files) for:
- `Global net ELEC energy = X.XXXE+XX kJ/mol` - Indicates successful completion
- No "Error" or "ASSERTION FAILURE" messages
- All `.dx` output files written successfully

### Common failure modes
- **Grid too small**: "Atom #X at (x, y, z) is off the mesh" - Increase `GRID_L`/`GRID_S` or adjust `GCENT`
- **Invalid dimensions**: Silent failure or segfault - Verify `DIME_*` follows formula: `dime = 2*c^(nlev+1) + 1`
- **Missing files**: Check `check_pdb_files()`, `check_pqr_files()`, `check_apbs_dirs()` validation functions
- **PDB2PQR errors**: Review `.log` files in PQR output directory for protonation issues

## Adding new workflow types

The repository is designed for extensibility. To add new workflows (e.g., mutagenesis, translocation):

1. Create new directory in `examples/` (e.g., `examples/mutagenesis/`)
2. Copy `justfile` pattern from `apbs_mspa/` and adapt recipes
3. Define workflow-specific `params.env` configuration
4. Add scripts to `scripts/` subdirectory matching workflow type
5. Reuse helper functions from `workflow_helpers.sh` where applicable

Each workflow should be self-contained with its own templates, force fields, and configuration.
