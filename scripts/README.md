# How to run the scripts in this folder

## Dependencies

- Python >3.10
- Modeller 10.x
- Bash

## Usage

### Prepare the nanopore input structure
  
Start from the OPM version of the pore [OPM 4uv3](https://opm.phar.umich.edu/proteins/2548)

 - Complete missing residues
 - Rotate the structure to the desired orientation: pore aligned with z-axis, and centered around in x and y around the pore center.
    - Start with the OPM structure
    - Use a molecular visualization tool (e.g., PyMOL, VMD) to manipulate the structure

In PyMOL, you can use the following commands to center and orient the CsgG structure:

```
rotate x, 180, camera=0
translate [0,0,61.31755], camera=0
save csgg_oriented.pdb, format=pdb
```

Extract the dummy membrane atoms from the OPM structure:
```
select membrane, resn DUM
extract
```

To determine the top and bottom cone radii, you can use the following commands:
```
alter_state 1, all, p.rad = (x*x +y*y)**0.5
select topradius_mem, membrane & z > 0 & p.rad > 30
select bottomradius_mem, membrane & z < 0 & p.rad > 28
```

### To create a mutant

Edit the file `01_create_csgg_mutant.sh` to specify your input PDB file, output PDB file, and mutations.
Next, run the script (in the background)

```bash
./01_create_csgg_mutant.sh > logs/01_create_csgg_mutant.log 2>&1 &
```
and follow the output with

```bash
tail -f logs/01_create_csgg_mutant.log
```

Open the resulting PDB with your favorite viewer and compare.

### To create a PQR file


### Run the electrostatics calculations

Settings for membrane:
  - CsgG: `zmem = -13.5`, `Lmem=27`, `R_top=`
