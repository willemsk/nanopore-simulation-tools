#!/bin/python

import sys
import numpy as np
import dxtools

def process_data(dxfile, base_fpath_out, radius):
  """Process DX file.

  Parameters
  ----------
  dxfile : str
      Path to input DX file.
  base_fpath_out : str
      Base file path used for output.
  radius : float
      Radius of the cylindrical average, must be > 0.
  """

  print('Processing file {:s} ... '.format(dxfile))

  # Load the data
  print('  Loading DXGrid ... ', end='')
  dxgrid_data = dxtools.load_dx_file(dxfile)
  print('done')

  # Create radial average
  print('  Creating radial average ... ', end='')
  [Xr, Yr, Zr] = dxtools._radial_average(
    dxgrid_data=dxgrid_data,
    dxgrid_mask=None,
    center=(0,0),
    bins=None # auto
  )
  print('done')

  # Save data
  outfile = base_fpath_out+'_radav'+'.csv'
  dxtools.write_csv(outfile, x=Xr, y=Yr, z=Zr)
  print('  Saved data in: {}'.format(outfile))

  # Create cylindrical average
  print('  Creating cylindrical average ... ', end='')
  [zpos, average] = dxtools._cylindrical_average(
    dxgrid_data=dxgrid_data,
    radius=radius,
    center=(0,0)
  )
  print('done')

  # Save data
  outfile = base_fpath_out+'_cylav'+'.csv'
  dxtools.write_csv(outfile, x=zpos, y=average)
  print('  Saved data in: {}'.format(outfile))
  

  # Extract slice
  for plane in ['xy', 'xz', 'yz']:
    print('  Creating {} slice ... '.format(plane), end='')
    if plane == 'xy':
      at = (np.abs(dxgrid_data.edges[2] - 0)).argmin() # closest index to 0
    else:
      at = None # auto

    [Xr, Yr, Zr] = dxtools._extract_slice(
      dxgrid=dxgrid_data,
      plane=plane,
      at=at
    )
    print('done')

    # Save data
    outfile = base_fpath_out+'_{}slice'.format(plane)+'.csv'
    dxtools.write_csv(outfile, x=Xr, y=Yr, z=Zr)
    print('  Saved data in: {}'.format(outfile))

  # Clear memory
  del dxgrid_data

def main(argv):
  """Main function for processing DX file.

  Parameters
  ----------
  argv : list
      1st el.: dxfile
      2nd el.: output directory
      3rd el.: radius for cylindrical average

  Returns
  -------
  int
      0 if completed successfully
  """
  from glob import glob
  from os import path, makedirs
  import ntpath

  if len(argv) != 3:
    print('Invalid number of arguments:')
    print(argv)
    return 1

  # Parse arguments
  dxfile = str(argv[0])
  directory_out = str(argv[1])
  radius = float(argv[2])

  if not path.exists(directory_out):
    makedirs(directory_out)

  # Get basename for outputfile
  basename = ntpath.basename(dxfile)[:-3]
  base_fpath_out = path.join(directory_out, basename)

  # Do processing
  process_data(dxfile, base_fpath_out, radius)

  return 0



if __name__ == "__main__":

  status = main(sys.argv[1:])

  exit(status)