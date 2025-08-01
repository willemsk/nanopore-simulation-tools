#! /bin/bash

################################################################################
# Electrostatics of ClyA
#
# Author: Kherim Willems
#         Michael Grabe
#         Nathan Baker
#
# This script does the following:
#   1. Selects a ClyA mutant
#   2. Draws the membrane around it by altering the maps from APBS
#   3. Carry out an electrostatics computation.
#   4. Repeat for other mutants
#
################################################################################


# Set the paths to the APBS and membrane drawing executable
echo
echo "Here are the binary locations:"
set -o verbose
apbs_bin=$(realpath ../bin/apbs-intel)
draw_bin=$(realpath ../bin/draw_membrane2)
merge_bin=$(realpath ../bin/mergedx2)

# Template files
echo
echo "These are the APBS template files you will use:"
apbs_dummy_template='../templates_apbs/apbs_dummy-TEMPLATE.in'
apbs_solv_template='../templates_apbs/apbs_solv-TEMPLATE.in'

# Working directory
echo
echo "This is the working directory:"
workdir='../output/csgg-mutants/apbs'

# Input directory
echo
echo "This is the PQR input directory:"
input_dir='../output/csgg-mutants/pqr'

# Input files
echo
echo "These are the input PQR files:"
pqrfiles=(\
    ${input_dir}/csgg_chimera_Y51R_oriented_pH7.0  \
    ${input_dir}/csgg_modeller_Y51R_oriented_pH7.0 \
    ${input_dir}/csgg_pymol_Y51R_oriented_pH7.0    \
    ${input_dir}/csgg_vmd_Y51R_oriented_pH7.0      \
    ${input_dir}/csgg_wt_oriented_pH7.0
)

set +o verbose

# Specify settings for the membrane calculation
echo
echo "Here are the problem settings you've chosen:"
set -o verbose

# General simuation settings
pdie=10.0          # protein dielectric value
sdie=80.0          # water dielectric value
ionr=2.0           # ion radius in Angstrom
ioncs=(\           # values of symmetric salt concentrations [M]
  0.15 \
#  2.50 \
)

# Membrane settings
zmem=-13.5         # lower leaflet z-position
Lmem=27            # thickness of the membrane
mdie=2.0           # membrane dielectric
memv=0.0           # Transmembrane potential. Doesn't work, but you need it.
R_top=16.0         # top membrane exclusion radius
R_bottom=14.0      # bottom membrane exclusion radius

# Grid settings
#
# Typical dime values 2*c^(nlev+1) + 1 for nlev=4
#   33,  65,  97, 129, 161, 193, 225, 257, 289, 321, 353, 385,
#   417, 449, 481, 513, 545, 577, 609

# gcent="mol 1"      # center of the grid is that of the molecule
gcent="0 0 30"     # center of the grid is at these coordinates

## Fine simulation
# grid_l="2.0 2.0 2.0"     # Grid spacing for large grid
# grid_s="0.5 0.5 0.5"     # Grid spacing for small grid
# dime_l="417 417 449"   # Number of grid points
# dime_s="417 417 449"   # Number of grid points


## Coarse simulation
grid_l="15 15 15"     # Grid spacing for large grid
grid_s="5 5 5"        # Grid spacing for small grid
dime_l="65 65 65"   # Number of grid points
dime_s="65 65 65"   # Number of grid points

## Fine simulation (if you fix the grid lengths)
# glen_l="900 900 900"   # Large grid length
# glen_s="300 300 200"   # Small grid length
# dime_l="609 609 417"   # Number of grid points
# dime_s="609 609 417"   # Number of grid points
set +o verbose


# Function definitions

#@create_apbs_input
#+Create an APBS input file from a template
#
function create_apbs_input {

  local template=$1
  local apbs_input=$2
  local ionc=${3}

  # Copy and replace
  cat $template | \
    sed -e "s/GCENT/${gcent}/g" | \
    sed -e "s/GLEN_L/${glen_l}/g" | \
    sed -e "s/GLEN_S/${glen_s}/g" | \
    sed -e "s/DIME_L/${dime_l}/g" | \
    sed -e "s/DIME_S/${dime_s}/g" | \
    sed -e "s/GRID_L/${grid_l}/g" | \
    sed -e "s/GRID_S/${grid_s}/g" | \
    sed -e "s/PDIE/${pdie}/g" | \
    sed -e "s/SDIE/${sdie}/g" | \
    sed -e "s/IONC/${ionc}/g" | \
    sed -e "s/IONR/${ionr}/g" \
    > $apbs_input

    return 0
}

#@run_apbs
#+Run APBS simulation
#
function run_apbs {
  local apbs_in=$1
  local apbs_out=$2

  local wd=$(dirname $(realpath $apbs_in))
  local cwd=$(pwd)
  (
    # Start timer
    SECONDS=0

    cd $wd
    echo "  Running '${apbs_in}' ..."
    ${apbs_bin} $(basename ${apbs_in}) > ${apbs_out}

    echo "    ... completed in ${SECONDS} seconds."
    cd $cwd
  ) &
  wait
}

#@draw_membrane
#+Draw membrane into coefficient maps
#
function draw_membrane {
  local diel=$1
  local ionc=$2


  local map=$(basename $diel)
  local wd=$(dirname $(realpath $diel))
  local cwd=$(pwd)
  (
    # Start timer
    SECONDS=0

    cd $wd
    echo "  Running '${draw_bin}' for '${map}' ..."
    ${draw_bin} $map $zmem $Lmem $pdie $memv $ionc $R_top $R_bottom > \
      "${map}_draw.log"

    echo "    ... completed in ${SECONDS} seconds."
    cd $cwd
  )
}

#@cleanup
#+Remove unnecessary files.
#
# 
#
function cleanup {
  local wd=$1
  rm ${wd}/*L.dx ${wd}/*S.dx
}

#@downsample
#+Downsample the maps to given grid size
# 
#
function downsample {
    map=$1
    grid=$2

    outmap="${${map}%.*}_${grid}A.dx"
    outlog="${${map}%.*}_${grid}A.log"
    $merge_bin -r $grid $grid $grid $map -o $outmap > $outlog

    return 0
}


# Create working directory if it doesn't exist already
echo "Creating working directory: ${workdir}..."
if [ ! -d ${workdir} ]; then
  mkdir -p ${workdir}
fi

# Loop over all PQR files
for pqrfile in ${pqrfiles[@]}; do

  pqr=$(basename "$pqrfile")

  # Loop over all salt concentrations
  for ionc in ${ioncs[@]}; do

    echo
    echo "Running ${pqr} at ${ionc} M salt."

    # Create working directory
    wdpqr="${workdir}/${pqr}/${ionc}"
    echo "  Creating working directory ${wdpqr}."
    if [ -d ${wdpqr} ]; then
      echo "  Warning: Folder ${wdpqr} already exists, removing."
      rm -fr ${wdpqr}
    fi
    mkdir -p ${wdpqr}

    # Create APBS input files
    echo "  Generating APBS input files ..."

    apbs_dummy_in="${wdpqr}/apbs_dummy.in"
    apbs_solv_in="${wdpqr}/apbs_solv.in"

    create_apbs_input $apbs_dummy_template $apbs_dummy_in $ionc
    create_apbs_input $apbs_solv_template $apbs_solv_in $ionc

    # Copy over the PQR file to the working directory
    echo "  Copying PQR file to working directory ..."

    cp "${pqrfile}.pqr" "${wdpqr}/TM.pqr"

    # Generate dummy maps
    echo "  Generating Poisson-Boltzmann coefficient maps with APBS ..."

    run_apbs $apbs_dummy_in "${pqr}_dummy.out"

    # Draw membrane
    echo "  Writing a membrane into the coefficient maps ..."

    dielL="${wdpqr}/dielx_L.dx"
    dielS="${wdpqr}/dielx_S.dx"

    draw_membrane $dielL $ionc
    draw_membrane $dielS $ionc

    # Run actual APBS simulation
    echo "  Running APBS calculations with the membrane ..."

    run_apbs $apbs_solv_in "${pqr}_solv.out"

    echo "  Done with ${pqr} at ${ionc} M salt."
    echo

    echo
    echo "Removing unneccesary files ..."
    cleanup ${wdpqr}
  done
done


echo
echo "Downsampling potential maps ..."
for FILE in ${workdir}/**/pot_Sm.dx; do
  (
    downsample $FILE 1
  ) &
done
wait

echo
echo "Downsampling kappa maps ..."
for FILE in ${workdir}/**/kappa_Sm.dx; do
  (
    downsample $FILE 1
  ) &
done
wait


echo "Done!"
exit 0
