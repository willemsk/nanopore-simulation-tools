#! /usr/bin/env bash
# run_pdb2pqr.sh — Batch PDB2PQR conversion for all PDB/CIF files in a directory
########################################################################################
# Converts all PDB or CIF files in a directory to PQR format using PDB2PQR. All
# output and logs are written to the specified output directory.
#
# This script is intended for batch conversion. If a required binary or
# directory is missing, a clear error message will be shown. For
# troubleshooting, check the log files in the output directory.
#
# Usage: ./run_pdb2pqr.sh [-h] [-c] -b PDB2PQR_BIN -i PDB_INPUT_DIR -o
#   PQR_OUTPUT_DIR [-p pH] [-q PDB2PQR_ARGS] [-v]
#
# @author Kherim Willems @author Francesco Quilli @date 26 October 2025
########################################################################################

set -e

# Usage information
print_usage() {
  printf "Usage: ./run_pdb2pqr.sh [-h] [-c] -b PDB2PQR_BIN -i PDB_INPUT_DIR -o PQR_OUTPUT_DIR [-p pH] [-q PDB2PQR_ARGS] [-v]\n"
  echo "  -b PDB2PQR_BIN   Path to pdb2pqr30 binary"
  echo "  -i PDB_INPUT_DIR Directory containing input PDB or CIF files"
  echo "  -o PQR_OUTPUT_DIR Directory to write PQR files and logs"
  echo "  -p pH            Target pH value (default: 7.0)"
  echo "  -q PDB2PQR_ARGS  Additional arguments for PDB2PQR"
  echo "  -c               Clean output directory before running"
  echo "  -v               Verbose output"
  echo "  -h               Show this help message"
  echo "\nAll output and logs are written to the specified output directory."
}

printf_verbose() {
  if [ "${verbose}" = "true" ]; then printf "$@"; fi
}

# Process input parameters
clean="false"
pdb2pqr_bin=""
pdb_input_dir=""
pqr_output_dir=""

ph="7.0"
pdb2pqr_args="--log-level INFO \
              --ff=CHARMM \
              --whitespace"
verbose="false"

while getopts 'hcb:i:o:p:q:v' flag; do
  case "${flag}" in
    h) print_usage
       exit 1 ;;
    c) clean="true" ;;
    b) pdb2pqr_bin="${OPTARG}" ;;
    i) pdb_input_dir="${OPTARG}" ;;
    o) pqr_output_dir="${OPTARG}" ;;
    p) ph="${OPTARG}" ;;
    q) pdb2pqr_args="${OPTARG}" ;;
    v) verbose="true" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [ ! -x "${pdb2pqr_bin}" ]; then
  echo "Error: Could not find pdb2pqr30 binary at '${pdb2pqr_bin}'! Please install PDB2PQR and provide the correct path with -b."
  exit 1
fi

if [ -z "${pdb_input_dir}" ]; then
  echo "Error: PDB input directory must be specified!"
  print_usage
  exit 1
fi

if [ -z "${pqr_output_dir}" ]; then
  echo "Error: PQR output directory must be specified!"
  print_usage
  exit 1
fi

pdb2pqr_args="${pdb2pqr_args} --with-ph=${ph}"

# Grab filenames of pdbs to convert
pdbfiles=( $(find ${pdb_input_dir} -maxdepth 1 -type f \( -name "*.pdb" -o -name "*.cif" \)) )

n=${#pdbfiles[@]}

if [ $n -eq 0 ]; then
  echo "Error: No PDB or CIF files found in ${pdb_input_dir}! Please check your input directory."
  exit 1
fi

# Create outputdir, clean it out if asked for
if [ ! -d "${pqr_output_dir}" ]; then
  mkdir -p "${pqr_output_dir}"
elif [ ${clean} == "true" ]; then
  rm -rf "${pqr_output_dir}"
  mkdir -p "${pqr_output_dir}"
fi

# Run PDB2PQR for each PDB file
i=0
n_files=${#pdbfiles[@]}

printf_verbose "Performing %s PDB2PQR runs at pH=%s.\n" ${n_files} ${ph}
printf_verbose "  Progress: 0 of %s completed (0.0%%)\n" ${n_files}

for pdbfile in ${pdbfiles[@]}; do
  # Define filenames
  base=$(basename "${pdbfile%.*}")
  pqr_out="${pqr_output_dir}/${base}_pH${ph}.pqr"
  log="${pqr_output_dir}/${base}_pH${ph}.log"

  # Run PDB2PQR
  printf_verbose "  Processing %-40s%-4s ... " "${pdbfile:0:40}" " "
  ${pdb2pqr_bin} ${pdb2pqr_args} ${pdbfile} ${pqr_out} > ${log} 2>&1
  printf_verbose "done → %s\n" ${pqr_out}

  i=$((i + 1))
  p=$(awk "BEGIN {printf \"%.1f\", ${i}*100.0/${n_files}}")
  printf_verbose "  Progress: %s of %s completed (%s%%)\n" ${i} ${n_files} ${p}
done

echo "PDB2PQR complete: Generated ${n_files} PQR files at pH ${ph}"
echo "Output directory: ${pqr_output_dir}"
echo "All logs are available in the output directory. If you encounter errors, check the corresponding .log files for details."

exit 0
