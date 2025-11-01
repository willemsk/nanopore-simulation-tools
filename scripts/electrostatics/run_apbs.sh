#! /usr/bin/env bash

########################################################################################
# USAGE
#
# $ ./run_apbs.sh [-h] -b APBS_BIN -m DRAW_BIN -d DIRSTRING [-v]
#
# Run APBS computations in the folders matching DIRSTRING.
#
# @author Kherim Willems
# @date 31 October 2025
########################################################################################

set -e

# Usage information
print_usage() {
  printf "Usage ./run_apbs.sh [-h] -b APBS_BIN -m DRAW_BIN -d DIRSTRING [-v]\n"
}

printf_verbose() {
  if [ "${verbose}" = "true" ]; then printf "$@"; fi
}

# Process input parameters
apbs_bin=""
draw_bin=""
dirstring=""
verbose="false"

while getopts 'b:m:d:hv' flag; do
  case "${flag}" in
    b) apbs_bin="${OPTARG}" ;;
    m) draw_bin="${OPTARG}" ;;
    d) dirstring="${OPTARG}" ;;
    h) print_usage
       exit 1 ;;
    v) verbose="true" ;;
    *) print_usage
       exit 1 ;;
  esac
done

# Check input validity
if [ ! -x "${apbs_bin}" ]; then
  printf "Error: Could not find APBS binary at: %s\n" "${apbs_bin}" >&2
  printf "\nPlease install APBS or update APBS_BIN path in justfile.\n" >&2
  printf "See README.md for installation instructions.\n" >&2
  print_usage
  exit 1
fi

if [ ! -x "${draw_bin}" ]; then
  printf "Error: Could not find draw_membrane2 binary at: %s\n" "${draw_bin}" >&2
  printf "\nPlease compile draw_membrane2 or check path in justfile.\n" >&2
  printf "See bin/README.md for compilation instructions.\n" >&2
  print_usage
  exit 1
fi

if [ -z "${dirstring}" ]; then
  printf "You must supply a run directory search string!\n"
  print_usage
  exit 1
fi

# Select which directories to run
apbs_directories=($(ls -d ${dirstring}*/* 2>/dev/null))
# Check for if there are no directories to run
if [ ${#apbs_directories[@]} -eq 0 ]; then
  printf "Error: No APBS run directories found matching: %s*/\n" "${dirstring}" >&2
  printf "\nHave you run 'just inputs' to prepare APBS input files?\n" >&2
  printf "Check that OUTPUT_DIR in params.env matches this path.\n" >&2
  exit 1
fi

# Check all directories contain required input files
for dir in ${apbs_directories[@]}; do
  for required_file in "apbs_dummy.in" "apbs_solv.in" "draw_membrane.in"; do
    infile="${dir}/${required_file}"
    if [ ! -f "${infile}" ]; then
      printf "Error: Missing required file '%s' in directory: %s\n" "${required_file}" "${dir}" >&2
      printf "\nRun 'just inputs' to generate APBS input files.\n" >&2
      exit 1
    fi
  done
done

# APBS execution wrapper
function run_apbs {
  local apbs_in=$1
  local apbs_out=$2
  local wd=$(realpath $(dirname $apbs_in))
  local cwd=$(pwd)
  local apbs_out_abs=$(realpath -m $apbs_out)
  mkdir -p $(dirname $apbs_out_abs)
  (
    SECONDS=0
    cd "$wd"
    printf_verbose "Running $(basename "$apbs_in") ... "
    ${apbs_bin} "$(basename "$apbs_in")" > "$apbs_out_abs"
    printf_verbose "completed in ${SECONDS} seconds.\n"
    cd "$cwd"
  )
}

function draw_membrane {
  local diel=$1
  local map=$(basename "$diel")
  local wd=$(dirname "$diel")
  local cwd=$(pwd)
  local params=$(cat "${wd}/draw_membrane.in")
  (
    SECONDS=0
    cd "$wd"
    printf_verbose "Drawing membrane for ${map} ... "
    ${draw_bin} ${map} ${params} > "${map}_draw.log"
    printf_verbose "completed in ${SECONDS} seconds.\n"
    cd "$cwd"
  )
}


# Run APBS for each directory
n=${#apbs_directories[@]}
printf_verbose "  Performing %s APBS runs in these directories:\n" ${n}
for dir in ${apbs_directories[@]}; do
  printf_verbose "    %s\n" "${dirstring}/${dir}"
done

for dir in ${apbs_directories[@]}; do

  printf_verbose "  Running APBS in directory: %s\n" "${dir}"

  # Define APBS input files
  apbs_dummy_in="${dir}/apbs_dummy.in"
  apbs_dummy_out="${dir}/apbs_dummy.out"
  apbs_solv_in="${dir}/apbs_solv.in"
  apbs_solv_out="${dir}/apbs_solv.out"

  printf_verbose "    Generating coefficient maps with dummy run. "
  run_apbs $apbs_dummy_in "${apbs_dummy_out}"

  printf_verbose "    Adding membrane to coarse grid. "
  dielL="${dir}/dielx_L.dx"
  draw_membrane $dielL

  printf_verbose "    Adding membrane to fine grid. "
  dielS="${dir}/dielx_S.dx"
  draw_membrane $dielS

  printf_verbose "    Executing electrostatic calculation. "
  run_apbs $apbs_solv_in "${apbs_solv_out}"

done

# Print completion summary
echo ""
echo "======================================================================"
echo "APBS execution complete"
echo "======================================================================"
echo "Processed ${n} run directories"
echo "Output location: ${dirstring}"
echo ""
echo "Next steps:"
echo "  - Validate results: just validate"
echo "  - View outputs: see EXPECTED_OUTPUT.md for file descriptions"
echo "  - Visualize: see VISUALIZATION.md for visualization instructions"

exit 0
