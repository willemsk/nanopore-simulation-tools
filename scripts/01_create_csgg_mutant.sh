#!/usr/bin/bash

MUTATE_BINARY=$(realpath "../bin/mutate_pdb.py")

INPUTFILE=$(realpath "../pdb/csgg_wt.pdb")
OUTPUTFILE=$(realpath "../pdb/csgg_modeller_Y51R.pdb")
MUTATIONS="ARG51:*"

${MUTATE_BINARY} --inputfile ${INPUTFILE} \
                 --outputfile ${OUTPUTFILE} \
                 --mutations ${MUTATIONS}
