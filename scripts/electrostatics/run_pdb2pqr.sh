#! /usr/bin/env bash
########################################################################################
# USAGE
#
# $ ./run_pdb2pqr.sh [-h] [-c] -b PDB2PQR_BIN -i PDB_INPUT_DIR -o PQR_OUTPUT_DIR [-p pH] [-q PDB2PQR_ARGS] [-v]
#
# Generates PQR files from PDB files in batch mode for a given pH.
#
# @author Kherim Willems
# @author Francesco Quilli
# @date 26 October 2025
########################################################################################

set -e

# Usage information
print_usage() {
  printf "Usage: ./run_pdb2pqr.sh [-h] [-c] -b PDB2PQR_BIN -i PDB_INPUT_DIR -o PQR_OUTPUT_DIR [-p pH] [-q PDB2PQR_ARGS] [-v]\n"
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
  echo "Error: Could not find pdb2pqr30 binary in PATH! Please install PDB2PQR."
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
  echo "Error: No PDB/CIF files found in ${pdb_input_dir}!"
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
# i=0


printf_verbose "Performing %s PDB2PQR runs at pH=%s.\n" ${n} ${ph}
# printf_verbose "  %g of %g completed (%.1f%%)" 0 ${n} 0.0

for pdbfile in ${pdbfiles[@]}; do
  # Define filenames
  base=$(basename "${pdbfile%.*}")
  pqr_out="${pqr_output_dir}/${base}_pH${ph}.pqr"
  log="${pqr_output_dir}/${base}_pH${ph}.log"

  # Run PDB2PQR
  printf_verbose "  Processing %-40s%-4s ... " "${pdbfile:0:40}" " "
  ${pdb2pqr_bin} ${pdb2pqr_args} ${pdbfile} ${pqr_out} > ${log} 2>&1
  printf_verbose "done → %s\n" ${pqr_out}

  # i=$(( i+1 ))
  # p=$((i*100/n))
  # printf_verbose "\r %g of %g completed (%.1f%%)" ${i} ${n} ${p}
done

exit 0
