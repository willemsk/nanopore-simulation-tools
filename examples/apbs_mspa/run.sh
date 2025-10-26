################################################################################
# vars.conf — Configuration file for APBS electrostatics calculations
################################################################################

# Input and output directories
pdb_input_dir="./pdb"         # input .pdb file location
output_dir="./OUTPUT"         # all generated results go here

# PDB2PQR settings
ph=(7.0)                  # values of pH to use; multiple values can be specified using a space-separated array, e.g., (7.0 7.4 7.8).
userff="./pdb2pqr_forcefield/mycharmm_spl2.dat"
usernames="./pdb2pqr_forcefield/mycharmm.names"

# APBS template input files
apbs_dummy_template="./apbs_templates/apbs_dummy-TEMPLATE.in"
apbs_solv_template="./apbs_templates/apbs_solv-TEMPLATE.in"

# APBS simulation settings
pdie=10.0                 # protein dielectric value
sdie=80.0    	          # water dielectric value
ionr=2.0                  # ion radius in Angstrom
ioncs=(0.15)              # values of symmetric salt concentrations [M]; multiple values can be specified using a space-separated array, e.g., (0.15 0.20).

# Membrane parameters
zmem=-18                  # lower leaflet z-position
Lmem=36                   # membrane thickness
mdie=2.0                  # membrane dielectric
memv=0.0                  # transmembrane potential
R_top=23.2                # upper leaflet membrane cutout
R_bottom=17.5             # bottom leaflet membrane cutout

# Grid settings
#
# Typical dime values 2*c^(nlev+1) + 1 for nlev=4
#   33,  65,  97, 129, 161, 193, 225, 257, 289, 321, 353, 385,
#   417, 449, 481, 513, 545, 577, 609

# Finer grid calculation settings
#gcent="0 0 30"           # center of the grid is at these coordinates
#grid_l="2.0 2.0 2.0"     # Grid spacing for large grid
#grid_s="0.5 0.5 0.5"     # Grid spacing fro small grid
#dime_l="417 417 449"     # Number of grid points 
#dime_s="417 417 449"     # Number of grid points

# Coarse grid calculation settings 
gcent="0 0 30"           # center of the grid is at these coordinates
grid_l="15 15 15"        # Grid spacing for large grid
grid_s="5 5 5"           # Grid spacing for small grid
dime_l="65 65 65"        # Number of grid points
dime_s="65 65 65"        # Number of grid points

################################################################################
# Advanced settings
################################################################################

# Executables
pdb2pqr_bin=$(which pdb2pqr30)
apbs_bin=$(realpath ../../bin/apbs-intel)
draw_bin=$(realpath ../../bin/draw_membrane2)


# Scripts
pdb2pqr_script=$(realpath ../../scripts/electrostatics/run_pdb2pqr.sh)
apbs_script=$(realpath ../../scripts/electrostatics/run_apbs.sh)

pqr_output_dir="${output_dir}/pqr"
apbs_output_dir="${output_dir}/apbs_runs"

################################################################################
# Helper functions
################################################################################

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

function create_draw_input {
  local draw_input=$1
  local ionc=$2
  echo "${zmem} ${Lmem} ${pdie} ${memv} ${ionc} ${R_top} ${R_bottom}" > "$draw_input"
}

################################################################################
# Run PDB2PQR to generate PQR files
################################################################################

for ph in ${ph[@]}; do
    printf "=== Running PDB2PQR at pH=%s ===\n" ${ph}
    pdb2pqr_args="--log-level=INFO \
                  --userff=${userff} \
                  --usernames=${usernames} \
                  --whitespace"

    ${pdb2pqr_script} -b ${pdb2pqr_bin} \
                      -i ${pdb_input_dir} \
                      -o ${pqr_output_dir} \
                      -p ${ph} \
                      -q "${pdb2pqr_args}" \
                      -v
done
printf "=== PDB2PQR conversion complete ===\n"

################################################################################
# Prepare APBS input files
################################################################################

pqrfiles=( $(find ${output_dir}/pqr -type f -name "*.pqr") )

for pqrfile in ${pqrfiles[@]}; do
  pqr=$(basename "$pqrfile" .pqr)

  for ionc in ${ioncs[@]}; do
    printf "=== Preparing input for %s at %s M salt ... " "${pqr}" "${ionc}"

    outdir="${apbs_output_dir}/${pqr}_${ionc}M"
    mkdir -p "${outdir}"

    apbs_dummy_in="${outdir}/apbs_dummy.in"
    apbs_solv_in="${outdir}/apbs_solv.in"
    create_apbs_input $apbs_dummy_template $apbs_dummy_in $ionc
    create_draw_input "${outdir}/draw_membrane.in" $ionc
    create_apbs_input $apbs_solv_template $apbs_solv_in $ionc

    cp "${pqrfile}" "${outdir}/TM.pqr"

    printf "done. ===\n"

  done
done


################################################################################
# Run APBS calculations
################################################################################

${apbs_script} -b ${apbs_bin} -m ${draw_bin} -d ${apbs_output_dir} -v

exit 0