#!/usr/bin/env python
# coding: utf-8

import sys

def compute_dime(c, nlev=4):
  """Compute dime, the number of grid points per processor.

  Parameters
  ----------
  c : int > 0
    Scaling factor.
  nlev : int
    Depth of multilevel hierarchy, optional (default: 4).
  
  Returns
  -------
  int
    Proper dime value.
  """
  try:
    c = int(c)
  except:
    raise Exception('Invalid c: {}'.format(c))
  if not c > 0:
    raise Exception('C must be integer > 0: {}'.format(c))
  
  return c * 2 ** (nlev + 1) +1


def best_dime(grid_size, grid_spacing, nlev=4):
  """Return the best dime value for the given grid properties."""
  import math

  mininum_dime = math.ceil(grid_size / grid_spacing)
  best_dime = 0

  c = 0
  while mininum_dime > best_dime:
    c += 1
    best_dime = compute_dime(c, nlev)
  
  return [best_dime, c, nlev]

def main(argv):
  """Main function for computing the proper dime value.

  Parameters
  ----------
  argv : list
      1st el.: grid size
      2nd el.: grid spacing
      3rd el.: nlev

  Returns
  -------
  int
      0 if completed successfully
  """

  if len(argv) < 2:
    print('Invalid number of arguments:')
    print(argv)
    return 1

  # Parse arguments
  grid_size = float(argv[0])
  grid_spacing = float(argv[1])
  if len(argv) > 2:
    nlev = int(argv[2])
  else:
    nlev = 4

  dime, c, nlev = best_dime(grid_size, grid_spacing, nlev)

  print('Best dime value for grid size {} with spacing {} ({:.1f} points) :'.format(grid_size, grid_spacing, grid_size/grid_spacing))
  print('dime = {}\nc = {}\nnlev= {}'.format(dime, c, nlev))


  return 0



if __name__ == "__main__":

  status = main(sys.argv[1:])

  exit(status)