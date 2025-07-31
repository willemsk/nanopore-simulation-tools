#!/usr/bin/python3

""" Program to create assign partially titration states
'''
    Usage: python fractionalpqr.py input/frac_re_2_PARSE.pqr input/frac_re.delpka delpka 4.5 PARSE frac_re_test_4.5
'''
"""

__date__ = "11 January 2017"
__author__ = "Kherim Willems"

import sys
import getopt
import copy
from typing import Literal

# PDB2PQR dependencies
import pdb2pqr.io as io
from pdb2pqr import (
    pdb
)
from pdb2pqr.pdb import (
    BaseRecord,
    register_line_parser,
    ATOM
)
from pdb2pqr.definitions import Definition

PROTONATED_RESNAMES_PARSE = {'ASP':'AS0','GLU':'GL0','TYR':'TYR','C-':'C-','ARG':'ARG','HIS':'HI+','LYS':'LYS','N+':'N+'}
DEPROTONATED_RESNAMES_PARSE = {'ASP':'ASP','GLU':'GLU','TYR':'TY-','C-':'C-','ARG':'AR0','HIS':'HIS','LYS':'LY0','N+':'N+'}

PROTONATED_RESNAMES_CHARMM = {'ASP':'ASPP','GLU':'GLUP','TYR':'TYR','C-':'C-','ARG':'ARG','HIS':'HSP','LYS':'LYS','N+':'N+'}
DEPROTONATED_RESNAMES_CHARMM = {'ASP':'ASP','GLU':'GLU','TYR':'TY-','C-':'C-','ARG':'AR0','HIS':'HIS','LYS':'LY0','N+':'N+'}

PROTONATED_DICT = {'PARSE': PROTONATED_RESNAMES_PARSE, 'CHARMM':PROTONATED_RESNAMES_CHARMM}
DEPROTONATED_DICT = {'PARSE': DEPROTONATED_RESNAMES_PARSE, 'CHARMM':DEPROTONATED_RESNAMES_CHARMM}

global verbose
verbose = False

@register_line_parser
class PROPKA(BaseRecord):
    """PROPKA class.

    This class represents a PROPKA record. It is used to parse the output of the
    PROPKA program line-by-line.
    """

    def __init__(
        self,
        line: str
    )  -> None:
        """Initialize by parsing a line.


        Parameters
        ----------
        line : str
            A line from the PROPKA output file.
            Example:
            "PROPKA ASP  10 A    4.36      3.80"

            COLUMNS  TYPE   FIELD    DEFINITION
            --------------------------------------------
             8-10    string resName Residue name.
            11-15    int    resSeq  Residue sequence number.
            16-18    string chainID Chain identifier.
            20-25    float  Predicted pKa.
        """
        super(PROPKA, self).__init__(line)
        # We add 7 characters to each index due to the artificial recordtype
        try:
            self.resName = line[6:10].strip()
        except ValueError:
            self.resName = None  # type: ignore
        try:
            self.resSeq = int(line[10:15].strip())
        except ValueError:
            self.resSeq = None  # type: ignore
        try:
            self.chainID = line[15:18].strip()
        except ValueError:
            self.chainID = None  # type: ignore
        try:
            self.pKaPre = float(line[19:25].strip())
        except ValueError:
            self.pKaPre = None  # type: ignore
        try:
            self.pKaMod = float(line[29:35].strip())
        except ValueError:
            self.pKaMod = None  # type: ignore

@register_line_parser
class DELPKA(BaseRecord):
    """DELPKA class.

    This class represents a DELPKA record. It is used to parse the output of the
    DELPKA program line-by-line.
    """

    def __init__(
        self,
        line: str
    ) -> None:
        """Initialize by parsing a line.

        Parameters
        ----------
        line : str
            A line from the DELPKA output file.
            Example:
            "DELPKA ARG0010A          11.66         0.2520        -0.0058              0.0124              0.0003"

            COLUMNS  TYPE   FIELD    DEFINITION
            --------------------------------------------
             8-10    string resName Residue name.
            11-15    int    resSeq  Residue sequence number.
            16-18    string chainID Chain identifier.
            20-25    float  Predicted pKa.
        """
        super(DELPKA, self).__init__(line)

        # We add 7 characters to each index due to the artificial recordtype
        # try:
        #     self.record = line[0:6].strip()
        # except ValueError:
        #     self.record = None
        try:
            self.resName = line[6:10].strip()
        except ValueError:
            self.resName = None  # type: ignore
        try:
            self.resSeq = int(line[10:14].strip())
        except ValueError:
            self.resSeq = None  # type: ignore
        try:
            self.chainID = line[14:17].strip()
        except ValueError:
            self.chainID = None  # type: ignore
        try:
            self.pKaPre = float(line[17:30].strip())
        except ValueError:
            self.pKaPre = None  # type: ignore
        try:
            self.ePolCharged = float(line[30:45].strip())
        except ValueError:
            self.ePolCharged = None  # type: ignore
        try:
            self.ePolNeutral = float(line[45:60].strip())
        except ValueError:
            self.ePolNeutral = None  # type: ignore
        try:
            self.eDeSolvCharged = float(line[60:80].strip())
        except ValueError:
            self.eDeSolvCharged = None  # type: ignore
        try:
            self.eDeSolvNeutral = float(line[80:100].strip())
        except ValueError:
            self.eDeSolvNeutral = None  # type: ignore


def read_pkas(
    filename: str,
    pka_type: Literal["PROPKA", "DELPKA"]
 ) -> list[PROPKA | DELPKA]:
    """Read pKa values from a file.

    Parameters
    ----------
    filename : str
        The name of the file to read.
    pka_type : Literal["PROPKA", "DELPKA"]
        The type of pKa values to read. Only outputs from PROPKA and DELPKA are supported.

    Returns
    -------
    list[Any]
        A list of pKa values.

    Raises
    ------
    ValueError
        If the file format given by `pka_type` is unknown.
    """

    match pka_type.upper():
        case "PROPKA":
            pka_section_end = "--------------------------------------------------------------------------------------------------------"
            pka_section_start = "RESIDUE    pKa   pKmodel   ligand atom-type"
            record_type = "PROPKA"
            # return read_PROPKA(filename)
        case "DELPKA":
            pka_section_end = ""
            pka_section_start = "RESIDUE    pKa   pKmodel   ligand atom-type"
            record_type = "DELPKA"
            # return readDELPKA(filename)
        case _:
            raise ValueError("Unknown fileFormat: ", pka_type)
    
    # Open file and process the records
    with open(filename, "rU") as file:
        pkalines = []
        add = False
        for line in file:
            line = line.strip()
            if line == pka_section_end:
                add = False
            if add:
                pkalines.append(f"{record_type} {line}")
            if line == pka_section_start:
                add = True

    # Create record objects of all the parsed lines
    pkalist: list[PROPKA | DELPKA] = []

    for line in pkalines:
        line = line.strip()
        record = line[0:6].strip()
        klass = pdb.LINE_PARSERS[record]
        obj = klass(line)
        pkalist.append(obj)

    return pkalist


def calculate_charged_fraction(
    pH: float,
    pKa: float,
    residue_name: str
) -> float:
    """Calculate the average charged fraction of a titratable residue.

    Parameters
    ----------
    pH : float
        Value of the solution pH.
    pKa : float
        pKa value of the titratable residue.
    residue_name : str
        Name of the titratable residue.

    Returns
    -------
    fraction : float
        Fraction of groups that are charged.
    """
    titration_type, full_charge = get_titration_type(residue_name)
    return full_charge / (1 + 10 ** (titration_type * (pH - pKa)))

def calculate_protonated_fraction(
    pH: float,
    pKa: float
) -> float:
    """Calculate the average protonated fraction.
    
    Parameters
    ----------
    pH: float
        Value of the solution pH.
    pKa: float
        pKa value of the titratable residue.
    Returns
    -------
    fraction : float
        The fraction of groups that are protonated
    """
    return 1 / (1 + 10 ** (pH - pKa))

def get_titration_type(
    residue_name: str
) -> tuple[float, float]:
    """Determines whether amino acid side chain is an acid or base.
    
    Parameters
    ----------
    residue_name : str
        Name of the titratable residue.

    Returns
    -------
    titration_type : float
        Type of titratable group: -1 for 'acid', +1 for 'base', and 0 for 'neutral'.
    full_charge : float
        Full charge if completely ionized.
    """
    acids = ['ASP','GLU','TYR','C-']
    bases = ['ARG','HIS','LYS','N+']

    if residue_name in acids:
        titration_type = -1
        full_charge = -1
    elif residue_name in bases:
        titration_type = +1
        full_charge = +1
    else:
        titration_type = 0
        full_charge = 0

    return titration_type, full_charge

# def read_pqr(
#     filename: str
# ):
#     """ Parse PQR-format data into array of Atom objects.
#         Charge and radius are stored into occupancy and tempFactor fields, resp.
#         Parameters
#           file:  open file object
#         Returns (pqrlist, errlist)
#           pqrlist:  a dictionary indexed by PDB record names
#           errlist:  a list of record names that couldn't be parsed
#     """

#     pqrlist = []  # Array of parsed lines (as objects)
#     errlist = []  # List of records we can't parse

#     with open(filename, "rU") as file:
#         while True:
#             line = file.readline().strip()
#             if not line:
#                 break
#         # We assume we have a method for each PDB record and can therefore
#         # parse them automatically
#         try:
#             record = line[0:6].strip()
#             if record not in errlist:
#                 klass = pdb.LINE_PARSERS[record]
#                 obj = klass(line)
#                 if record == "ATOM" or record == "HETATM":
#                     charge = float(line[55:62])
#                     radius = float(line[63:69])
#                     obj.occupancy = charge
#                     obj.tempFactor = radius
#                 pqrlist.append(obj)
#         except KeyError as details:
#             errlist.append(record)
#             sys.stderr.write("Error parsing line: %s\n" % details)
#             sys.stderr.write("<%s>\n" % string.strip(line))
#             sys.stderr.write("Truncating remaining errors for record type:%s\n" % record)
#         except StandardError as details:
#             if record == "ATOM" or record == "HETATM":
#                 try:
#                     obj = readAtom(line)
#                     pqrlist.append(obj)
#                 except StandardError as details:
#                     sys.stderr.write("Error parsing line: %s\n" % details)
#                     sys.stderr.write("<%s>\n" % string.strip(line))
#             elif record == "SITE" or record == "TURN":
#                 pass
#             elif record == "SSBOND" or record == "LINK":
#                 sys.stderr.write("Warning -- ignoring record: \n")
#                 sys.stderr.write("<%s>\n" % string.strip(line))
#             else:
#                 sys.stderr.write("Error parsing line: %s\n" % details)
#                 sys.stderr.write("<%s>\n" % string.strip(line))

#     return pqrlist, errlist

def write_pqr(
    atomlist: list[ATOM],
    filename: str
) -> None:
    with open(filename, "w") as file:
        for line in io.print_biomolecule_atoms(atomlist, chainflag=True):
            file.write(line)

def transfer_atom_properties(
    protein
) -> None:
    atoms = protein.getAtoms()
    for a in atoms:
        a.ffcharge = a.occupancy
        a.radius = a.tempFactor



def adjustChargeProtein(protein, pH, pkalist, ff):
    global verbose
    verboseprint = print if verbose else lambda *a, **k: None

    residues = protein.getResidues()

    for res in residues:
        pka = next((pka for pka in pkalist if ((pka.chainID == res.chainID and pka.resSeq == res.resSeq))), None)
        if pka != None:
            fraction = calculate_protonated_fraction(pH, pka.pKaPre)
            verboseprint('FPQR>> Patching %s %.0f %s with pKa %.2f to be %.2f %% protonated at pH %.2f' % (pka.resName, pka.resSeq, pka.chainID, pka.pKaPre, fraction*100, pH))
            adjustChargeResidue(res, fraction, pka.resName, ff)

def adjustChargeResidue(residue, fraction, resname, ff):

    prdict = PROTONATED_DICT[ff.name]
    dedict = DEPROTONATED_DICT[ff.name]

    prResName = prdict[resname]
    deResName = dedict[resname]

    for a in residue.getAtoms():

        prcharge, prradius = ff.getParams(prResName, a.name)
        decharge, deradius = ff.getParams(deResName, a.name)

        if prcharge == None:
            prcharge = 0
        if decharge == None:
            decharge = 0

        a.ffcharge = prcharge*fraction + decharge*(1-fraction)


'''
    Usage: python fractionalpqr.py input/frac_re_2_PARSE.pqr input/frac_re.delpka delpka 4.5 PARSE frac_re_test_4.5
'''
def main(argv):
    try:
        opts, args = getopt.getopt(argv,"hvi:o:k:t:p:f:l:",["help", "verbose", "input_file=","output_file=", "pka_file=", "pka_type=", "ph=", "forcefield="])
    except getopt.GetoptError:
        print('fractionalpqr.py -i <pqr_inputfile> -o <pqr_outputfile> -k <pka_inputfile> -t <pkatype> -p <ph> -f <forcefield>')
        sys.exit(2)

    global verbose
    verbose = False
    pqr_in = ''
    pqr_out = ''
    pka_in = ''
    pka_type = ''
    ff = ''
    pH = ''

    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print('fractionalpqr.py -i <pqr_inputfile> -o <pqr_outputfile> -k <pka_inputfile> -t <pkatype> -p <ph> -f <forcefield>')
            sys.exit()
        elif opt in ("-v", "--verbose"):
            verbose = True
        elif opt in ("-i", "--input_file"):
            pqr_in = arg
        elif opt in ("-o", "--output_file"):
            pqr_out = arg
        elif opt in ("-k", "--pka_file"):
            pka_in = arg
        elif opt in ("-t", "--pka_type"):
            pka_type = arg
        elif opt in ("-f", "--forcefield"):
            ff = arg
        elif opt in ("-p", "--ph"):
            pH = arg

    # Verbose print function
    verboseprint = print if verbose else lambda *a, **k: None

    # pH is must be float
    pH = float(pH)
    # parameter names must be all caps
    pka_type = pka_type.upper()
    ff = ff.upper()

    verboseprint('**************************************************************')
    verboseprint('FPQR>> Input PQR file is ' + pqr_in)
    verboseprint('FPQR>> Output PQR file is ' + pqr_out)
    verboseprint('FPQR>> Input PKA file is ' + pka_in + ' and of type ' + pka_type)
    verboseprint('FPQR>> Forcefield to use is ' + ff)
    verboseprint('FPQR>> Generate PQR at pH ' + str(pH))
    verboseprint('**************************************************************')

    verboseprint('FPQR>> Creating calculation environment ...', end='')
    # Create a definition object
    myDef = Definition()
    verboseprint('done.',end='\n')

    verboseprint('FPQR>> Reading in atom coordinates, charges and radii from %s ...' % ( pqr_in ), end='')
    # Read in PQR file, charge and radius are stored in occupancy and tempFactor
    atomlist, errlist = read_pqr(open(pqr_in, "rU"))
    verboseprint('done.',end='\n')

    verboseprint('FPQR>> Reading in per residue pKa-values from %s ...' % ( pka_in ), end='')
    # Read in the PKA file to generate a list of PKA objects
    pkalist = read_pkas(pka_in, pka_type)
    verboseprint('done.',end='\n')

    # Create forcefield
    verboseprint('FPQR>> Loading %s forcefield parameters ...' % ( ff ), end='')
    myff = Forcefield(ff,myDef,None,None)
    verboseprint('done.',end='\n')

    # Create a new protein object from the list of atoms
    pqrprotein = Protein(atomlist,myDef)
    # Transfer charge and radius to the correct fields
    transfer_atom_properties(pqrprotein)

    # Adjust charges
    verboseprint('FPQR>> Adjusting partial charges according to their fractional charged state at pH %.2f ...' % (pH), end = '\n')
    newpqrprotein = copy.deepcopy(pqrprotein)
    adjustChargeProtein(newpqrprotein, pH, pkalist,myff)

    verboseprint('FPQR>> Writing adjusted PQR file to %s ...' % ( pqr_out ), end='')
    write_pqr(newpqrprotein, pqr_out)
    verboseprint('done.',end='\n')

    verboseprint('**************************************************************')
    verboseprint('\nFPQR>> All done! Thank you for using fractionalpqr! ;)\n')
    verboseprint('**************************************************************')


if __name__ == "__main__":
	main(sys.argv[1:])
