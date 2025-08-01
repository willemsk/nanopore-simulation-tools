#!/usr/bin/bash

MUTATE_BINARY=$(realpath "../bin/mutate_pdb.py")

INPUTFILE=$(realpath "../pdb/csgg_wt.pdb")
OUTPUTFILE=$(realpath "../output/csgg-mutants/pdb/csgg_modeller_Y51R.pdb")
MUTATIONS="ARG51:*"

if [ ! -d $(dirname ${OUTPUTFILE}) ]; then
    mkdir -p $(dirname ${OUTPUTFILE})
fi

${MUTATE_BINARY} --inputfile ${INPUTFILE} \
                 --outputfile ${OUTPUTFILE} \
                 --mutations ${MUTATIONS} > log.txt 2>&1
