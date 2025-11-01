# Contributing to nanopore simulation tools

## Reporting issues

If you encounter bugs or have feature requests, please open an issue on the [GitHub repository](https://github.com/willemsk/nanopore-simulation-tools/issues) with:
- A clear description of the problem or request
- Steps to reproduce (for bugs)
- Your environment details (OS, APBS version, PDB2PQR version)
- Relevant error messages or log outputs

## Adapting workflows

This toolkit is designed to be extensible for different nanopore systems and simulation types.

### Using other proteins

1. Copy the `examples/apbs_mspa` directory to e.g.,`examples/apbs_prot`
2. Replace the PDB file(s) in `examples/apbs_prot/pdb/`
3. Adjust membrane parameters (`ZMEM`, `LMEM`, `R_TOP`, `R_BOTTOM`) for your system geometry
4. Run the workflow: `just all`

### Modifying force fields

The custom CHARMM force field in `pdb2pqr_forcefield/` can be adapted for specialized residues or non-standard chemistry. See the [PDB2PQR documentation on custom force fields](https://pdb2pqr.readthedocs.io/en/latest/extending.html#adding-new-forcefield-parameters) for detailed information on force field modification.

### Creating new workflow types

To add capabilities beyond electrostatics (e.g., mutagenesis, translocation energy landscapes):

1. Create a new directory under `examples/` (e.g., `examples/mutagenesis/`)
2. Define workflow-specific parameters in a `params.env` file
3. Add orchestration scripts to `scripts/<workflow_type>/`
4. Create a `justfile` adapted from the `apbs_mspa` pattern
5. Include templates and force fields as needed

Each workflow should be self-contained with its own documentation.

## Code style

Shell scripts follow these conventions:
- Use `set -e` for immediate exit on errors
- Use `bash` (not `sh`) for script compatibility
- Include usage/help information in script headers
- Document helper functions with inline comments
- Use `workflow_helpers.sh` functions for consistency

## Questions

For questions about usage or contributions, please open a discussion on the GitHub repository.
