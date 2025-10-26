#! /usr/bin/env bash

########################################################################################
# USAGE
#
# $ ./run_apbs.sh [-h] -b APBS_BIN -m DRAW_BIN -d DIRSTRING [-v]
#
# Run APBS computations in the folders matching DIRSTRING.
#
# @author Kherim Willems
# @date 21 August 2018
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
  printf "Could not find APBS binary at: %s. Please install APBS.\n" "${apbs_bin}"
  print_usage
  exit 1
fi

if [ ! -x "${draw_bin}" ]; then
  printf "Could not find draw_membrane2 binary at: %s\n." "${draw_bin}"
  print_usage
  exit 1
fi

if [ -z "${dirstring}" ]; then
  printf "You must supply a run directory search string!\n"
  print_usage
  exit 1
fi

# Select which directories to run
apbs_directories=($(ls ${dirstring}*/))
# Check for if their are no directories to run
if [ ! $? -eq 0 ]; then
  printf "  No APBS directories found using this DIRSTRING: %s\n" ${dirstring}
  exit 1
fi

# Check all directories contain apbs_dummy.in file
for dir in ${apbs_directories[@]}; do
  infile="${dirstring}/${dir}/apbs_dummy.in"
  if [ ! -f ${infile} ]; then
    printf "  No `apbs_dummy.in` input file found in directory: %s\n" "${dirstring}/${dir}"
    exit 1
  fi
done

# Check all directories contain apbs_solv.in file
for dir in ${apbs_directories[@]}; do
  infile="${dirstring}/${dir}/apbs_solv.in"
  if [ ! -f ${infile} ]; then
    printf "  No `apbs_solv.in` input file found in directory: %s\n" "${dirstring}/${dir}"
    exit 1
  fi
done

# Check all directories contain draw_membrane.in file
for dir in ${apbs_directories[@]}; do
  infile="${dirstring}/${dir}/draw_membrane.in"
  if [ ! -f ${infile} ]; then
    printf "  No `draw_membrane.in` input file found in directory: %s\n" "${dirstring}/${dir}"
    exit 1
  fi
done



# APBS execution wrapper
function run_apbs {
  local apbs_in=$1
  local apbs_out=$2
  local wd=$(dirname "$(realpath "$apbs_in")")
  local cwd=$(pwd)
  local apbs_out_abs="$(realpath -m "$apbs_out")"
  mkdir -p "$(dirname "$apbs_out_abs")"
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

  outdir="${dirstring}/${dir}"
  printf_verbose "  Running APBS in directory: %s\n" "${outdir}"

  # Define APBS input files
  apbs_dummy_in="${dirstring}/${dir}/apbs_dummy.in"
  apbs_solv_in="${dirstring}/${dir}/apbs_solv.in"

  printf_verbose "    Generating coefficient maps with dummy run. "
  run_apbs $apbs_dummy_in "${apbs_dummy_in}.out"

  printf_verbose "    Adding membrane to coarse grid. "
  dielL="${outdir}/dielx_L.dx"
  draw_membrane $dielL

  printf_verbose "    Adding membrane to fine grid. "
  dielS="${outdir}/dielx_S.dx"
  draw_membrane $dielS

  printf_verbose "    Executing electrostatic calculation. "
  run_apbs $apbs_solv_in "${apbs_solv_in}.out"

done

exit 0
