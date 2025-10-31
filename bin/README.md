# Pre-compiled binaries (convenience option)

This directory contains pre-compiled binaries as a convenience option for users who cannot easily build from source. **We recommend building APBS from source for best compatibility with your system.**

## Contents

### `apbs-intel`
Pre-compiled APBS (Adaptive Poisson-Boltzmann Solver) binary built with Intel compilers for x86_64 architecture.

**Compatibility:**
- Architecture: x86_64 (Intel/AMD 64-bit)
- May not work on ARM-based systems (Apple M1/M2, ARM servers)
- Requires compatible system libraries (glibc, libgomp, etc.)

**To use:**
The `justfile` in `examples/apbs_mspa/` automatically detects this binary if APBS is not in your PATH.

**Recommended alternative:**
Build APBS from source for optimal performance and compatibility:
```bash
git clone https://github.com/Electrostatics/apbs.git
cd apbs
mkdir build && cd build
cmake -DENABLE_OPENMP=ON ..
make -j4
sudo make install
```

### `draw_membrane2`
Membrane modeling utility compiled from APBS examples. This tool modifies APBS coefficient maps to include lipid membrane dielectric boundaries.

**Source:**
Originally from [APBS examples](https://github.com/Electrostatics/apbs/blob/main/examples/helix/draw_membrane2.c)

**To rebuild:**
```bash
cd bin/
wget https://raw.githubusercontent.com/Electrostatics/apbs/main/examples/helix/draw_membrane2.c
gcc -O3 -o draw_membrane2 draw_membrane2.c -lm
```

## License

These binaries are compiled from open-source projects:
- APBS is licensed under BSD 3-Clause License
- `draw_membrane2` source is part of APBS examples

See the respective project repositories for complete license information.
