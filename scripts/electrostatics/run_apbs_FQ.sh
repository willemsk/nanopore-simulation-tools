#! /bin/bash
################################################################################
# Electrostatics of a biological nanopore with membrane
#
# Author: Kherim Willems
#         Michael Grabe
#         Nathan Baker
#
# This script does the following:
#   1. Selects a nanopore mutant
#   2. Draws the membrane around it by altering the maps from APBS
#   3. Carry out an electrostatics computation.
#   4. Repeat for other mutants
#
################################################################################
# calculation.sh — Full pipeline: PDB2PQR + APBS + membrane
################################################################################

set -e

# Load configuration
if [ ! -f "./vars.conf" ]; then
  echo "Error: vars.conf not found in scripts/!"
  exit 1
fi
source ./vars.conf

# Define paths
BIN_DIR="$(realpath ../bin)"
apbs_bin="${BIN_DIR}/${apbs_bin}"
draw_bin="${BIN_DIR}/${draw_bin}"
pdb2pqr_bin=$(which ${pdb2pqr_bin})

echo
echo "Loaded configuration from vars.conf"
echo "APBS binary: ${apbs_bin}"
echo "DRAW_MEMBRANE binary: ${draw_bin}"
echo "PDB2PQR binary: ${pdb2pqr_bin}"
echo "PDB input dir: ${pdb_input_dir}"
echo "Output dir: ${pqr_output_dir}"
echo

################################################################################
# Step 1: PDB2PQR
################################################################################

echo "=== Running PDB2PQR ==="
mkdir -p "${pqr_output_dir}"

pdb2pqr_args="--log-level INFO \
              --userff=${userff} \
              --usernames=${usernames} \
              --whitespace \
              --with-ph=${ph}"

pdbfiles=( $(find ${pdb_input_dir} -maxdepth 1 -type f \( -name "*.pdb" -o -name "*.cif" \)) )

if [ ${#pdbfiles[@]} -eq 0 ]; then
  echo "Error: No PDB/CIF files found in ${pdb_input_dir}!"
  exit 1
fi

for pdbfile in ${pdbfiles[@]}; do
  base=$(basename "${pdbfile%.*}")
  pqr_out="${pqr_output_dir}/${base}_pH${ph}.pqr"
  log="${pqr_output_dir}/${base}_pH${ph}.log"

  echo "  Processing ${base} ..."
  ${pdb2pqr_bin} ${pdb2pqr_args} ${pdbfile} ${pqr_out} > ${log} 2>&1
  echo "    Done → ${pqr_out}"
done

echo "=== PDB2PQR complete ==="
echo

################################################################################
# Step 2: APBS + Membrane
################################################################################

pqrfiles=( $(find ${pqr_output_dir} -type f -name "*.pqr") )

function create_apbs_input {
  local template=$1
  local apbs_input=$2
  local ionc=$3
  cat "$template" | \
    sed -e "s/GCENT/${gcent}/g" \
        -e "s/DIME_L/${dime_l}/g" \
        -e "s/DIME_S/${dime_s}/g" \
        -e "s/GRID_L/${grid_l}/g" \
        -e "s/GRID_S/${grid_s}/g" \
        -e "s/PDIE/${pdie}/g" \
        -e "s/SDIE/${sdie}/g" \
        -e "s/IONC/${ionc}/g" \
        -e "s/IONR/${ionr}/g" \
    > "$apbs_input"
}

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
    echo "  Running $(basename "$apbs_in") ..."
    ${apbs_bin} "$(basename "$apbs_in")" > "$apbs_out_abs"
    echo "    ... completed in ${SECONDS} seconds."
    cd "$cwd"
  )
}

function draw_membrane {
  local diel=$1
  local ionc=$2
  local map=$(basename "$diel")
  local wd=$(dirname "$diel")
  local cwd=$(pwd)
  (
    SECONDS=0
    cd "$wd"
    echo "  Drawing membrane for ${map} ..."
    ${draw_bin} "$map" $zmem $Lmem $pdie $memv $ionc $R_top $R_bottom > "${map}_draw.log"
    echo "    ... completed in ${SECONDS} seconds."
    cd "$cwd"
  )
}

for pqrfile in ${pqrfiles[@]}; do
  pqr=$(basename "$pqrfile" .pqr)

  for ionc in ${ioncs[@]}; do
    echo
    echo "Running ${pqr} at ${ionc} M salt."

    outdir="${pqr_output_dir}/${pqr}_${ionc}M"
    mkdir -p "${outdir}"

    apbs_dummy_in="${outdir}/apbs_dummy.in"
    apbs_solv_in="${outdir}/apbs_solv.in"
    create_apbs_input $apbs_dummy_template $apbs_dummy_in $ionc
    create_apbs_input $apbs_solv_template $apbs_solv_in $ionc

    cp "${pqrfile}" "${outdir}/TM.pqr"

    echo "  Generating coefficient maps with APBS ..."
    run_apbs $apbs_dummy_in "${outdir}/${pqr}_dummy.out"

    dielL="${outdir}/dielx_L.dx"
    dielS="${outdir}/dielx_S.dx"
    draw_membrane $dielL $ionc
    draw_membrane $dielS $ionc

    echo "  Running APBS with membrane ..."
    run_apbs $apbs_solv_in "${outdir}/${pqr}_solv.out"
    echo "  Completed ${pqr} at ${ionc} M salt."
  done
done

echo
echo "=== All calculations complete ==="
exit 0

