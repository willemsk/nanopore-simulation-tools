#! /usr/bin/env sh

##################################################
# USAGE
#
# $ ./process_dx_data [-h] -i INPUTDIR -o OUTPUTDIR [-v]
#
# Extracts the xy, xz and yz-slices, radial average
#and cylindrical center average from the dx files
# found in the input directory and saves them as
#.csv files in the output directory.
# Output maintains the same folder structure as the
# input directories. 
#
# Example:
# $ ./process_dx_data.sh -i ../../data/electrostatics  -o data
#
# @author Kherim Willems @date 05 June 2020
##################################################

# Usage information
print_usage() {
  printf "Usage: ./process_dx_data [-h] -i INPUTDIR -o OUTPUTDIR [-v]\n"
  exit 1
}

# Process input parameters
inputdir=""
outputdir=""
verbose="false"

while getopts 'i:o:hv' flag; do
  case "${flag}" in
    i) inputdir="${OPTARG}" ;;
    o) outputdir="${OPTARG}" ;;
    h) print_usage ;;
    v) verbose="true" ;;
    *) print_usage ;;
  esac
done

if [ -z "${inputdir}" ] || [ -z "${outputdir}" ]; then
    print_usage
fi

printf_verbose() {
  if [ "${verbose}" = "true" ]; then printf "$@"; fi
}

# Binary location
dx_processing_bin='./process_dx_file.py'

###################################################
# Script start

# List of paths to input dx files
FILES=$(find ${inputdir} -name '*.dx')

process_filename() {
  local file=$1

  local fullpath=$(realpath $file)
  local patharray=($(echo ${fullpath%*.dx} | tr "/" "\n"))
  local reloutpath=${patharray[@]: -4:4}
  reloutdir=${reloutpath// /\/}
  pore=${patharray[-4]}
}

get_radius() {
  case "${pore}" in
    clya) radius=15 ;;
    frac) radius=6 ;;
    plyab) radius=25 ;;
    *) printf "Unsopported pore: ${pore}"
       exit 1 ;;
  esac
}

for dxfile in $FILES; do
  # Create arguments for processing script
  process_filename $dxfile

  # Set full output dir
  dxfile=$(realpath $dxfile)
  csv_outdir="$(realpath $outputdir)/${reloutdir}"

  # Determine radius
  get_radius $pore

  # Do the processing
  set -o verbose
  ${dx_processing_bin} ${dxfile} ${csv_outdir} ${radius}
  set +o verbose
done
