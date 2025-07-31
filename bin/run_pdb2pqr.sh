#! /usr/bin/env bash

################################################################################
# USAGE
#
# $ ./run_pdb2pqr.sh [-h] [-c] -r RUNDIR [-n NPROC] [-p PDB2PQR_ARGS] [-v]
#
# Generates PQR files from PDB files in parallel.
#
# @author Kherim Willems
# @date 21 August 2018
################################################################################

set -e

# PDB2PQR binary location
pdb2pqr_bin=$(which pdb2pqr30)
cwd=$(pwd)

# Usage information
print_usage() {
  printf "Usage ./run_pdb2pqr.sh [-h] [-c] -r RUNDIR [-n NPROC] [-p PDB2PQR_ARGS] [-v]\n"
}

printf_verbose() {
  if [ "${verbose}" = "true" ]; then printf "$@"; fi
}

# Process input parameters
clean="false"
nproc=1
run_dir=""
#pdb2pqr_args="--verbose --ff=charmm --chain --whitespace --ph-calc-method=propka --with-ph=7.5"
#pdb2pqr_args="--verbose --userff=../pdb2pqr/mycharmm_spl2.dat --usernames=../pdb2pqr/mycharmm.names --chain --whitespace --ph-calc-method=propka --with-ph=7.5 --assign-only"
pdb2pqr_args="--log-level INFO --userff=../pdb2pqr/mycharmm_spl2.dat --usernames=../pdb2pqr/mycharmm.names --whitespace --assign-only"
verbose="false"

while getopts 'chr:n:p:v' flag; do
  case "${flag}" in
    c) clean="true" ;;
    h) print_usage
       exit 1 ;;
    r) run_dir="${OPTARG}" ;;
    n) nproc="${OPTARG}" ;;
    p) pdb2pqr_args="${OPTARG}" ;;
    v) verbose="true" ;;
    *) print_usage
       exit 1 ;;
  esac
done

input_dir="${run_dir}/pdb"
output_dir="${run_dir}/pqr"

# Grab filenames of pdbs to convert
cd "${input_dir}"
pdbfiles=$(find . -type f \( -name "*.pdb" -o -name "*.cif" \) )
cd ${cwd}

printf_verbose "Running PDB2PQR for these PDB files:\n"
for pdbfile in ${pdbfiles[@]}; do
  printf_verbose "\t%s\n" ${pdbfile}
done

# PDB2PQR execution wrapper
run_pdb2pqr() {
  local pdb_in=$1; shift
  local pqr_out=$1; shift
  local log=$1; shift
  local pdb2pqr_args="$@"

  ${pdb2pqr_bin} ${pdb2pqr_args} ${pdb_in} ${pqr_out} >> ${log}
}

run_wait() {
  sleep 5
}

open_sem(){
    mkfifo pipe-$$
    exec 3<>pipe-$$
    rm pipe-$$
    local i=$1
    for((;i>0;i--)); do
        printf %s 000 >&3
    done
}
run_with_lock(){
    local x
    read -u 3 -n 3 x && ((0==x)) || exit $x
    (
     ( "$@"; )
    printf '%.3d' $? >&3
    )&
}

# Count the number of runs completed
i=0
n=$(echo "${pdbfiles}" | wc -l)

open_sem ${nproc}

# Limit the number of concurrent processes
# Run PDB2PQR for each directoy
printf_verbose "Performing %s PDB2PQR runs on %s processors.\n" ${n} ${nproc}
printf_verbose "  %g of %g completed (%.1f%%)" 0 ${n} 0.0

# Create outputdir, clean it out if asked for
if [ ! -d "${output_dir}" ]; then
  mkdir -p "${output_dir}"
elif [ ${clean} == "true" ]; then
  rm -rf "${output_dir}"; mkdir -p "${output_dir}"
fi


for pdbfile in ${pdbfiles[@]}; do
  echo $pdbfile
  # Define filenames
  filename=$(basename -- "${pdbfile}")
  file="${filename%.*}"
  extension="${filename##*.}"
  pdb_in="${input_dir}/${file}.${extension}"
  pqr_out="${output_dir}/${file}.pqr"
  log="${output_dir}/${file}.log"
  # Run PDB2PQR
  run_with_lock run_pdb2pqr ${pdb_in} ${pqr_out} ${log} ${pdb2pqr_args}
  #run_with_lock run_wait
  i=$(( i+1 ))
  p=$((i*100/n))
  printf_verbose "\r %g of %g completed (%.1f%%)" ${i} ${n} ${p}
done
wait < <(jobs -p)

printf_verbose "\nAll done!\n"
exit 0
