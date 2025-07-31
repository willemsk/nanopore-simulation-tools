#! /usr/bin/env bash

########################################################################################
# USAGE
#
# $ ./run_apbs.sh [-h] -d DIRSTRING [-n NPROC] [-v]
#
# Run NPROC parallel APBS computations in the folders matching DIRSTRING.
#
# @author Kherim Willems
# @date 21 August 2018
########################################################################################

set -e

# APBS binary location
apbs_bin=$(realpath ../bin/apbs-intel)
cwd=$(pwd)

# Usage information
print_usage() {
  printf "Usage ./run_apbs.sh [-h] -d DIRSTRING [-n NPROC] [-v]\n"
}

printf_verbose() {
  if [ "${verbose}" = "true" ]; then printf "$@"; fi
}

# Process input parameters
nproc=1
dirstring=""
verbose="false"

while getopts 'd:n:hv' flag; do
  case "${flag}" in
    d) dirstring="${OPTARG}" ;;
    n) nproc="${OPTARG}" ;;
    h) print_usage
       exit 1 ;;
    v) verbose="true" ;;
    *) print_usage
       exit 1 ;;
  esac
done

# Check input validity
if [ -z "${dirstring}" ]; then
  printf "You must supply a directory search string with the -d option!\n"
  exit 1
fi

# Select which directories to run
apbs_directories=($(ls ${dirstring}*/))
# Check for if their are no directories to run
if [ ! $? -eq 0 ]; then
  printf "No APBS directories found using this DIRSTRING: %s\n" ${dirstring}
  exit 1
fi

# Check if some directory does not contain an APBS .in file
for dir in ${apbs_directories[@]}; do
  infile="${dirstring}/${dir}/apbs.in"
  if [ ! -f ${infile} ]; then
    printf "No APBS input file found in directory: %s\n" "${dirstring}/${dir}"
    exit 1
  fi
done

printf_verbose "Running APBS in these directories:\n"
for dir in ${apbs_directories[@]}; do
  printf_verbose "\t%s\n" "${dirstring}/${dir}"
done

# Routines for parallel execution
open_sem() {
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
  "$@"
  printf '%.3d' $? >&3
  )&
}

# Counting vars
i=0
n=${#apbs_directories[@]}

# APBS execution wrapper
run_apbs(){
  local dir=$1
  SECONDS=0
  cd ${dir}
  apbs_in="apbs.in"
  apbs_out="apbs.out"
  echo "PQR_FILE: $dir" > ${apbs_out}
  ${apbs_bin} ${apbs_in} &>> ${apbs_out}
  cd ${cwd}
  echo "APBS run for completed in ${SECONDS} seconds.\n" >> ${apbs_out}
}

# APBS execution wrapper
run_sleep(){
  sleep $1
}


# Limit the number of concurrent processes
open_sem ${nproc}
# Run APBS for each directoy
printf_verbose "Performing %s APBS runs on %s processors.\n" ${n} ${nproc}
printf_verbose "  %g of %g completed (%.1f%%)" 0 ${n} 0.0
for dir in ${apbs_directories[@]}; do
  run_with_lock run_apbs "${dirstring}/${dir}"
  sleep 10
  #run_with_lock run_sleep 0.5
  i=$(( i+1 ))
  p=$(( 100 * i / n ))
  printf_verbose "\r  %g of %g completed (%.1f%%)" ${i} ${n} ${p}
done
wait

printf_verbose "\nAll done!\n"
exit 0
