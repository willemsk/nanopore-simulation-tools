#!/usr/bin/env bash

set -e

# PDB2PQR binary location
pdb2pqr_bin=$(which pdb2pqr30)

input_dir="../output/csgg-mutants/pdb"
output_dir="../output/csgg-mutants/pqr"

ph=7.0

pdb2pqr_args="--log-level INFO \
              --userff=../pdb2pqr/mycharmm_spl2.dat \
              --usernames=../pdb2pqr/mycharmm.names \
              --whitespace \
              --with-ph=${ph}"


if [ ! -d $output_dir ]; then mkdir -p $output_dir; fi

# Grab all PDBs from input directory
pdbfiles=$(find ${input_dir} -type f \( -name "*oriented.pdb" -o -name "*oriented.cif" \) )

# Run PDB2PQR
for pdbfile in ${pdbfiles[@]}; do
  printf "Processing file: %s ... " "$pdbfile"
  # Define filenames
  filename=$(basename -- "${pdbfile}")
  file="${filename%.*}"
  extension="${filename##*.}"
  pdb_in="${input_dir}/${file}.${extension}"
  pqr_out="${output_dir}/${file}_pH${ph}.pqr"
  log="${output_dir}/${file}_pH${ph}.log"
  # Run PDB2PQR
  ${pdb2pqr_bin} ${pdb2pqr_args} ${pdb_in} ${pqr_out} > ${log} 2>&1
  printf "done ... saved as ${pqr_out}\n"
done
