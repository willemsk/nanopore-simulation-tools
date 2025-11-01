#!/usr/bin/env bash
################################################################################
# validate_output.sh — Validate APBS workflow output completeness
################################################################################
# Checks that all expected output files exist and calculations completed
# successfully by parsing APBS output logs for success markers.
#
# This script should be run after all APBS calculations are complete. It checks
# for missing files and for the "Total electrostatic energy" success marker in
# each run directory. If validation fails, check your grid and membrane settings
# in params.env and rerun the affected calculations.
#
# Usage:
#   ./validate_output.sh -o OUTPUT_DIR [-v]
#
# Options:
#   -o OUTPUT_DIR  Directory containing apbs_runs/ subdirectories
#   -v             Verbose output (show all checks)
#   -h             Show help
#
# Exit codes:
#   0  All validations passed
#   1  One or more validations failed
#
# @author Kherim Willems
# @date 2025-10-31
################################################################################

set -e

# Usage information
print_usage() {
  cat << EOF
Usage: ./validate_output.sh -o OUTPUT_DIR [-v]

Validate APBS workflow output completeness and correctness.

Options:
  -o OUTPUT_DIR  Base output directory (contains apbs_runs/ subdirectory)
  -v             Verbose output (show all validation checks)
  -h             Show this help message

Exit codes:
  0  All validations passed
  1  One or more validations failed

Example:
  ./validate_output.sh -o OUTPUT/ -v
EOF
}

# Process command line arguments
output_dir=""
verbose="false"

while getopts 'o:vh' flag; do
  case "${flag}" in
    o) output_dir="${OPTARG}" ;;
    v) verbose="true" ;;
    h) print_usage
       exit 0 ;;
    *) print_usage
       exit 1 ;;
  esac
done

# Verbose printf
printf_verbose() {
  if [ "${verbose}" = "true" ]; then
    printf "$@"
  fi
}

# Validate input
if [ -z "${output_dir}" ]; then
  echo "Error: Output directory not specified" >&2
  print_usage
  exit 1
fi

if [ ! -d "${output_dir}" ]; then
  echo "Error: Output directory does not exist: ${output_dir}" >&2
  exit 1
fi

# Locate APBS run directories
apbs_runs_dir="${output_dir}/apbs_runs"
if [ ! -d "${apbs_runs_dir}" ]; then
  echo "Error: APBS runs directory not found: ${apbs_runs_dir}" >&2
  echo "  Have you run 'just inputs' and 'just apbs'?" >&2
  exit 1
fi

# Find all run directories
run_dirs=($(find "${apbs_runs_dir}" -mindepth 1 -maxdepth 1 -type d | sort))
n_dirs=${#run_dirs[@]}

if [ ${n_dirs} -eq 0 ]; then
  echo "Error: No APBS run directories found in ${apbs_runs_dir}" >&2
  echo "  Run 'just inputs' to create run directories" >&2
  exit 1
fi

echo "Validating ${n_dirs} APBS run directories..."
echo ""

# Validation counters
n_complete=0
n_missing_files=0
n_missing_energy=0
validation_failed=0

# Critical files that must exist
critical_files=(
  "TM.pqr"
  "pot_Lm.dx"
  "pot_Sm.dx"
  "apbs_solv.out"
)

# Validate each directory
for run_dir in "${run_dirs[@]}"; do
  dir_name=$(basename "${run_dir}")
  printf_verbose "Checking ${dir_name}...\n"
  
  # Check for critical files
  missing_files=0
  for file in "${critical_files[@]}"; do
    if [ ! -f "${run_dir}/${file}" ]; then
      if [ ${missing_files} -eq 0 ]; then
        echo "  ✗ ${dir_name}: Missing files"
      fi
      echo "    - ${file}"
      missing_files=1
      validation_failed=1
    else
      printf_verbose "    ✓ ${file} exists\n"
    fi
  done
  
  if [ ${missing_files} -eq 1 ]; then
    n_missing_files=$((n_missing_files + 1))
    continue
  fi
  
  # Check for APBS success marker in output log
  out_file="${run_dir}/apbs_solv.out"
  if grep -q "Total electrostatic energy" "${out_file}"; then
    energy=$(grep "Total electrostatic energy" "${out_file}" | tail -1 | awk '{print $5, $6}')
    printf_verbose "    ✓ APBS completed successfully (energy: ${energy})\n"
    n_complete=$((n_complete + 1))
  else
    echo "  ✗ ${dir_name}: APBS calculation may have failed"
    echo "    - No 'Total electrostatic energy' found in apbs_solv.out"
    echo "    - This usually indicates a grid or input error. Check ${out_file} for errors and review your params.env settings."
    n_missing_energy=$((n_missing_energy + 1))
    validation_failed=1
  fi
  
  printf_verbose "\n"
done

# Print summary
echo ""
echo "======================================================================"
echo "Validation Summary"
echo "======================================================================"
echo "Total directories:           ${n_dirs}"
echo "Complete and successful:     ${n_complete}"
echo "Missing critical files:      ${n_missing_files}"
echo "Missing energy calculation:  ${n_missing_energy}"
echo ""

if [ ${validation_failed} -eq 0 ]; then
  echo "✓ All validations passed!"
  echo ""
  echo "Next steps:"
  echo "  - View results: see VISUALIZATION.md for visualization instructions"
  echo "  - Extract energies: grep 'Total electrostatic energy' ${apbs_runs_dir}/*/apbs_solv.out"
  exit 0
else
  echo "✗ Validation failed"
  echo ""
  echo "To fix issues:"
  echo "  1. Check error messages in .out files for failed directories"
  echo "  2. Verify grid and membrane settings in params.env (see EXPECTED_OUTPUT.md)"
  echo "  3. Re-run incomplete calculations: just resume or just all"
  exit 1
fi
