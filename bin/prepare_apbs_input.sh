#! /usr/bin/env bash

########################################################################################
# USAGE
#
# $ ./prepare_apbs_input.sh [-h] [-c] -r RUNDIR -t APBS_TEMPLATE [-v]
#
# Prepares the folder structure and the input files for an APBS run.
#
# @author Kherim Willems
# @date 21 August 2018
########################################################################################

set -e

cwd=$(pwd)

# Usage information
print_usage() {
  printf "Usage ./prepare_apbs_input.sh [-h] [-c] -r RUNDIR -t APBS_TEMPLATE [-v]\n"
}

printf_verbose() {
  if [ "${verbose}" = "true" ]; then printf "$@"; fi
}

# Process input parameters
clean="false"
nproc=1
run_dir=""
apbs_template=""
verbose="false"

while getopts 'chr:t:v' flag; do
  case "${flag}" in
    c) clean="true" ;;
    h) print_usage
       exit 1 ;;
    r) run_dir="${OPTARG}" ;;
    v) verbose="true" ;;
    t) apbs_template="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

input_dir="${run_dir}/pqr"
output_dir="${run_dir}/apbs"

# Check input validity
if [ -z "${input_dir}" ]; then
  printf "You must supply an input directory with the -i option!\n"
  print_usage
  exit 1
fi

if [ -z "${output_dir}" ]; then
  printf "You must supply an output directory with the -o option!\n"
  print_usage
  exit 1
fi

if [ ! -f "${apbs_template}" ]; then
  printf "You must supply a valid APBS template file with the -t option!\n"
  print_usage
  exit 1
fi

# Cleanup output directory if needed
if ([ "${clean}" == "true" ] && [ -d ${output_dir} ]); then
  printf_verbose "Removing entire output directory... "
  rm -rf ${output_dir}
  printf_verbose "Done.\n"
fi

# Prepare input files
printf_verbose "Preparing APBS input folders and files... "
# Grab filenames of pdbs to convert
cd ${input_dir}
pqrfiles=$(find . -type f -name "*.pqr")
cd ${cwd}

# Copy over files
for pqrfile in $pqrfiles; do
  file=$(basename ${pqrfile} .pqr)
  # Create directory
  apbs_dir="${output_dir}/${file}"
  if [ ! -d ${apbs_dir} ]; then
    mkdir -p ${apbs_dir}
  fi
  # Copy over files
  cp -f "${input_dir}/${pqrfile}" "${apbs_dir}/SYSTEM.pqr"
  cp -f "${apbs_template}" "${apbs_dir}/apbs.in"
done
printf_verbose "Done.\n"

wait;

printf_verbose "All done!\n"
exit 0
