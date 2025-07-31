# How to run the scripts in this folder

## Dependencies

- Python >3.10
- Modeller 10.x
- Bash

## Usage

### To create a mutant

Edit the file `01_create_csgg_mutant.sh` to specify your input PDB file, output PDB file, and mutations.
Next, run the script (in the background)

```bash
./01_create_csgg_mutant.sh > logs/01_create_csgg_mutant.log &
```
and follow the output with

```bash
tail -f logs/01_create_csgg_mutant.log
```

Open the resulting PDB with your favorite viewer and compare.

### To create a PQR file

