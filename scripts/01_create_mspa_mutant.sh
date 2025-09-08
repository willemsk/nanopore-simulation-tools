#!/usr/bin/bash

MUTATE_BINARY=$(realpath "../bin/mutate_pdb.py")

INPUTFILE=$(realpath "../pdb/chimera_mspa_oriented.pdb")
OUTPUTFILE="../output/mspa-mutants/pdb/mspa_chimera_wt.pdb"
MUTATIONS="ARG51:*"

if [ ! -d $(dirname ${OUTPUTFILE}) ]; then
    mkdir -p $(dirname ${OUTPUTFILE})
fi

# ${MUTATE_BINARY} --inputfile ${INPUTFILE} \
                #  --outputfile ${OUTPUTFILE} \
#                  --mutations ${MUTATIONS} > log.txt 2>&1

cp ${INPUTFILE} ${OUTPUTFILE}
