#!/usr/bin/python3
"""Program that allows one to make single or multiple mutations in a PDB file.

Example usage
-------------
```
$ python mutate_pdb.py -i input.pdb -o output.pdb -m 'ALA5:A,PRO90:B'
```

The `-i` flag denotes the path to the inputfile PDB file, the `-o` flag denotes the output file.
The `-m` flag 'RES1RESN1:CHAIN1,RES2RESN2:CHAIN2' indicates which mutations to perform,
e.g., 'ALA5:A,PRO90:B'. You can use '*' in the chain identifier to mutate that residue in all chains.
"""

import os
import argparse
from typing import Literal

from modeller import (
    Alignment,
    Environ,
    Model,
    Alignment,
    Selection,
    log
)
from modeller.optimizers import (
    ConjugateGradients,
    MolecularDynamics
)
from modeller.automodel import autosched
from modeller.schedule import Schedule

__author__ = "Kherim Willems"
__copyright__ = "Copyright 2025, imec"
__credits__ = ["Kherim Willems"]
__license__ = "GPL"
__version__ = "0.1.0"
__maintainer__ = "Kherim Willems"
__email__ = "Kherim.Willems@imec.be"
__status__ = "Testing"

def optimize(
    atmsel: Selection,
    sched: Schedule
) -> None:
    """
    Optimize the given atom selection using the specified schedule.

    Will first perform a conjugate gradient optimization using the supplied
    schedule, followed by molecular dynamics refinement and a final conjugate
    gradient optimization.

    Parameters
    ----------
    atmsel : Selection
        The atom selection to optimize.
    sched : Schedule
        The schedule to use for optimization.
    """
    # Conjugate gradient 1
    for step in sched:
        step.optimize(atmsel, max_iterations=200, min_atom_shift=0.001)
    # Molecular dynamics
    refine(atmsel)
    cg = ConjugateGradients()
    # Conjugate gradient 2
    cg.optimize(atmsel, max_iterations=200, min_atom_shift=0.001)


def refine(
    atmsel: Selection
) -> None:
    """
    Refine the selected atoms using molecular dynamics.

    Parameters
    ----------
    atmsel : Selection
        The selected atoms to refine.
    """
    # at T=1000, max_atom_shift for 4fs is cca 0.15 A.
    md = MolecularDynamics(
        cap_atom_shift=0.39,
        md_time_step=4.0,
        md_return="FINAL"
    )
    init_vel = True
    for (its, equil, temps) in (
        (200,  20, (150.0, 250.0, 400.0, 700.0, 1000.0)),
        (200, 600, (1000.0, 800.0, 600.0, 500.0, 400.0, 300.0))
    ):
        for temp in temps:
            md.optimize(atmsel, init_velocities=init_vel, temperature=temp,
                         max_iterations=its, equilibrate=equil)
            init_vel = False


#use homologs and dihedral library for dihedral angle restraints
def make_restraints(
    mdl1: Model,
    aln: Alignment
) -> None:
   rsr = mdl1.restraints
   rsr.clear()
   s = Selection(mdl1)
   for typ in ("stereo", "phi-psi_binormal"):
       rsr.make(s, restraint_type=typ, aln=aln, spline_on_site=True)
   for typ in ("omega", "chi1", "chi2", "chi3", "chi4"):
       rsr.make(s, restraint_type=typ+"_dihedral", spline_range=4.0,
                spline_dx=0.3, spline_min_points = 5, aln=aln,
                spline_on_site=True)

# Convert mutation string into residue_type, residue_number and chain
def parse_mutation(mutation_string):
    chain_delim_index = mutation_string.find(":")
    restype = mutation_string[:3]
    resnum = mutation_string[3:chain_delim_index]
    reschain = mutation_string[chain_delim_index+1:]
    return restype,resnum,reschain


def mutate_residue(
    model: Model,
    mutation: str
) -> None:
    """Mutate one or more residue in the model.

    Parameters
    ----------
    model : Model
        The protein model to mutate.
    mutation : str
        The mutation to apply in the format <restype><resnum>:<reschain>. Using
        '*' as the chain identifier will mutate that residue in all chains,
        e.g., 'ALA5:A', 'PRO90:B', or 'GLY10:*'.
    """

    restype, resnum, reschain = parse_mutation(mutation)

    if reschain == "*":
        chains = model.chains
        for c in chains:
            s = Selection(c.residues[resnum])
            s.mutate(residue_type=restype)
    else:
        s = Selection(model.chains[reschain].residues[resnum])
        s.mutate(residue_type=restype)

def select_mutations(
    model: Model,
    mutations: list[str]
) -> Selection:
    """Create an atom selection for a model from a list of mutations.

    Parameters
    ----------
    model : Model
        The model to select atoms from.
    mutations : list[str]
        The list of mutations to apply.

    Returns
    -------
    Selection
        The atom selection for the specified mutations.
    """
    s = Selection()
    for m in mutations:
        restype, resnum, reschain = parse_mutation(m)
        if reschain == "*":
            # We'll have to go over every chain...
            chains = model.chains
            for c in chains:
                s.add(c.residues[resnum])
        else:
            s.add(model.chains[reschain].residues[resnum])
    return s

def main(
    infilename: str,
    outfilename: str,
    mutations: list[str]
) -> Literal[0]:
    """Main method for mutating PDB file.

    Parameters
    ----------
    infilename : str
        Path to the input PDB file.
    outfilename : str
        Path to the output PDB file.
    mutations : list[str]
        List of mutations to perform.

    Returns
    -------
        0 if successful

    Raises
    ------
    AssertionError
        If input or output files are not PDB files, or if no valid mutations are provided.
    FileNotFoundError
        If the input file does not exist.
    OSError
        If there are issues creating directories or writing files.
    Exception
        For other errors encountered during mutation or file operations.
    """

    # Get current working directory
    cwd = os.getcwd()
    
    # Get full path to inputfile
    inmodel_path = os.path.realpath(infilename)
    # Get full path to outputfile
    outmodel_path = os.path.realpath(outfilename)

    # Strip the extension of inputfile
    inmodel_path = inmodel_path[:-4]
    # Get output directory only
    outdir = os.path.dirname(outmodel_path)
    # Get output filename only without extension
    outname = os.path.basename(outmodel_path)[:-4]

    # Create output directory if needed
    os.makedirs(outdir, exist_ok=True)
    # Change working dir
    os.chdir(outdir)

    # Start logging
    log.verbose()

    # Set a different value for rand_seed to get a different final model
    env = Environ(rand_seed=-49837)

    env.io.hetatm = True  # ignore: type
    #soft sphere potential
    env.edat.dynamic_sphere = False
    #lennard-jones potential (more accurate)
    env.edat.dynamic_lennard = True
    env.edat.contact_shell = 4.0
    env.edat.update_dynamic = 0.39

    # Read customized topology file with phosphoserines (or standard one)
    env.libs.topology.read(file="$(LIB)/top_heav.lib")

    # Read customized CHARMM parameter library with phosphoserines (or standard one)
    env.libs.parameters.read(file="$(LIB)/par.lib")

    # Read the original PDB file and copy its sequence to the alignment array:
    mdl1 = Model(env, file=inmodel_path)
    ali = Alignment(env)
    ali.append_model(mdl1, atom_files=inmodel_path, align_codes=inmodel_path)

    # Mutate each residue
    for m in mutations:
        mutate_residue(mdl1,m)


    #get two copies of the sequence.  A modeller trick to get things set up
    ali.append_model(mdl1, align_codes=inmodel_path)

    # Generate molecular topology for mutant
    mdl1.clear_topology()
    mdl1.generate_topology(ali[-1])


    # Transfer all the coordinates you can from the template native structure
    # to the mutant (this works even if the order of atoms in the native PDB
    # file is not standard):
    # here we are generating the model by reading the template coordinates
    mdl1.transfer_xyz(ali)

    # Build the remaining unknown coordinates
    mdl1.build(initialize_xyz=False, build_method="INTERNAL_COORDINATES")

    # Yes model2 is the same file as model1.  It's a modeller trick.
    mdl2 = Model(env, file=inmodel_path)

    # Required to do a transfer_res_numb
    # ali.append_model(mdl2, atom_files=modelname, align_codes=modelname)
    # transfers from "model 2" to "model 1"
    mdl1.res_num_from(mdl2,ali)

    # It is usually necessary to write the mutated sequence out and read it in
    # before proceeding, because not all sequence related information about MODEL
    # is changed by this command (e.g., internal coordinates, charges, and atom
    # types and radii are not updated).

    mdl1.write(file=outname+".tmp")
    mdl1.read(file=outname+".tmp")

    # set up restraints before computing energy
    # we do this a second time because the model has been written out and read in,
    # clearing the previously set restraints
    make_restraints(mdl1, ali)

    # a non-bonded pair has to have at least as many selected atoms
    mdl1.env.edat.nonbonded_sel_atoms = 1

    sched = autosched.loop.make_for_model(mdl1)

    # only optimize the selected residue (in first pass, just atoms in selected
    # residue, in second pass, include nonbonded neighboring atoms)
    # set up the mutate residue selection segment
    s = select_mutations(mdl1,mutations)

    mdl1.restraints.unpick_all()
    mdl1.restraints.pick(s)

    s.energy()

    s.randomize_xyz(deviation=4.0)

    mdl1.env.edat.nonbonded_sel_atoms=2
    optimize(s, sched)

    # feels environment (energy computed on pairs that have at least one member
    # in the selected)
    mdl1.env.edat.nonbonded_sel_atoms = 1
    optimize(s, sched)

    s.energy()

    # Give a proper name
    mdl1.write(file=outname+".pdb")

    # Delete the temporary file
    os.remove(outname+".tmp")

    # Change back to CWD
    os.chdir(cwd)

    return 0


if __name__ == "__main__":
    program_args = argparse.ArgumentParser(description="PDB mutator script")
    program_args.add_argument(
        "-i", "--inputfile" , required=True,
        help="Input file path"
    )
    program_args.add_argument(
        "-o", "--outputfile", required=True,
        help="Output file path"
    )
    program_args.add_argument(
        "-m", "--mutations", required=True,
        help="Mutations to perform. 'RES1RESN1:CHAIN1,RES2RESN2:CHAIN2' e.g., 'ALA5:A,PRO90:B'."
    )

    args = program_args.parse_args()

    if args.inputfile:
        infilename = args.inputfile
        assert ".pdb" in infilename.lower(), "Unsupported file: 'only .PDB files are supported as input.'"
    if args.outputfile:
        outfilename = args.outputfile
        assert ".pdb" in outfilename.lower(), "Unsupported file: 'only .PDB files are supported as output.'"
    if args.mutations:
        mutations = args.mutations.split(",")
        assert len(mutations) > 0, "No valid mutations could be parsed."

    status = main(infilename, outfilename, mutations)

    if status == 0:
        print("################################")
        print("Mutagenesis successful! Exiting.")
        print("################################")
