import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from numba import njit, prange
from gridData import Grid

import scipy
from scipy import ndimage

def load_dx_file(dxfile):
  return Grid(dxfile)

def create_meshgrid(dxgrid):
  """Create a meshgrid for the dxgrid.
  
  Arguments:
      dxgrid {gridData.Grid} -- OpenDX grid
  
  Returns:
      [X, Y, Z] -- X, Y, Z meshgrid matrices for data
  """
  shape = dxgrid.grid.shape
  delta = dxgrid.delta
  origin = dxgrid.origin

  xv = range(0,shape[0])*delta[0]+origin[0]+delta[0]
  yv = range(0,shape[1])*delta[1]+origin[1]+delta[1]
  zv = range(0,shape[2])*delta[2]+origin[2]+delta[2]

  X, Y, Z = np.meshgrid(xv,yv,zv)
  return [X, Y, Z]

  """Plot a slice through a grid
  
  Arguments:
      dxgrid {Grid} -- OpenDX grid object
  
  Keyword Arguments:
      plane {'yz' or 'xz' or 'xy'} -- Plane to slice (default: {'yz'})

    Raises:
      ValueError: if plane is not 'yz' or 'xz' or 'xy'
  
  Returns:
      {mesh} -- pcolormesh graph
  """

def _extract_slice(dxgrid, plane='yz', at=None):
  """Extract slice from DX grid.

  Parameters
  ----------
  dxgrid : Grid
      OpenDX grid object
  plane : str, optional
      Plane to slice ({'yz' or 'xz' or 'xy'}), by default 'yz'
  at : int, optional
      Index to slice, by default None (auto center index)

  Returns
  -------
  list of 3 array_like
      [Xp, Yp, data]

  Raises
  ------
  ValueError
      If you choose a non-cartesian slice.
  """

  shape = dxgrid.grid.shape
  delta = dxgrid.delta

  X,Y,Z = create_meshgrid(dxgrid)

  if plane == 'yz':
    if at is None:
      at = int(shape[0]/2)
    Xp = X[at,:,:] - delta[0]
    Yp = Z[at,:,:] - delta[2]
    data = dxgrid.grid[at,:,:]
  elif plane == 'xz':
    if at is None:
      at = int(shape[1]/2)
    Xp = Y[:,at,:] - delta[1]
    Yp = Z[:,at,:] - delta[2]
    data = dxgrid.grid[:,at,:]
  elif plane == 'xy':
    if at is None:
      at = int(shape[2]/2)
    Xp = X[:,:,at] - delta[0]
    Yp = Y[:,:,at] - delta[1]
    data = dxgrid.grid[:,:,at]
  else:
    raise ValueError('Unsupported slice plane: {}'.format(plane))

  return [Xp, Yp, data]

def extract_slice(dxgrid_file, plane='yz', at=None):
  """Extract a slice from the given DX grid file.

  Parameters
  ----------
  dxgrid_file : str
      Path to DX file
  plane : str, optional
      Plane to slice ({'yz' or 'xz' or 'xy'}), by default 'yz'
  at : int, optional
      Index to slice, by default None (auto center index)

  Returns
  -------
  list of 3 array_like
      [Xp, Yp, data]
  """
  return _extract_slice(dxgrid=Grid(dxgrid_file), plane=plane, at=at)


def plot_slice(dxgrid, plane='yz', at=0, ax=None, **kwargs):
  """Plot a slice through a grid
  
  Arguments:
      dxgrid {Grid} -- OpenDX grid object
  
  Keyword Arguments:
      plane {'yz' or 'xz' or 'xy'} -- Plane to slice (default: {'yz'})
      at {int} -- Index to slice through (default: {0})
      ax {Axes} -- Axes object to plot in (default: {None})

    Raises:
      ValueError: if plane is not 'yz' or 'xz' or 'xy'
  
  Returns:
      {mesh} -- pcolormesh graph
  """

  Xp, Yp, data = _extract_slice(dxgrid, plane, at)

  if ax == None:
    ax = plt.gca()

  pc = ax.pcolormesh(Xp, Yp, data, **kwargs)
  return pc

@njit(parallel=True)
def create_radial_mask(r, h, z, X, Y, Z):
  """Create a cylindrical mask for gridded data.
  
  Arguments:
      r {float} -- Radius of cylinder
      h {float} -- Height of cylinder
      z {float} -- Central z-position of cylinder
      X {ndarray} -- 3D meshgrid for x coordinates
      Y {ndarray} -- 3D meshgrid for y coordinates
      Z {ndarray} -- 3D meshgrid for z coordinates
  
  Returns:
      {ndarray} -- Cylindrical mask
  """
  
  Rf = np.sqrt(np.power(X,2) + np.power(Y,2)) <= r
  Zf = (Z <= (z + h/2)) & (Z >= (z - h/2))
  
  return Rf & Zf


def _radial_average(dxgrid_data, dxgrid_mask=None, center=(0,0), bins=None):
  """Compute radial average along the z-axis.

  Parameters
  ---------
    dxgrid_data : {Grid}
      DX grid to radially average.
    dxgrid_mask : {Grid or None}
      DX grid to use as a mask (default: {None})
    center : {tuple}
      Center of radial average (default: {(0,0)})
    bins : {int or list} 
      Bins to use for the averaging (default: {None})

  Returns
  -------
      [Xr Yr Zr]
        List of the meshgrids (Xr and Yr) and the radially averaged data (Zr).
  """

  if bins is None:
    shape = np.array(dxgrid_data.grid.shape)
    delta = np.array(dxgrid_data.delta)
    origin = np.array(dxgrid_data.origin)
    extent = ((shape-1) * delta)
    bins = np.arange(0, extent[0]/2 + delta[0], delta[0])


  # Create meshgrid
  X,Y,Z = create_meshgrid(dxgrid_data)
  
  # Compute a radius coordinate meshgrid relative to center
  r = np.hypot(X[:,:,0]-center[0], Y[:,:,0]-center[1])

  averages = []
  for zi in np.arange(0,Z.shape[2]):

    # Create slice of data
    if dxgrid_mask:
      mask = ~dxgrid_mask.grid[:,:,zi].astype(np.bool)
    else:
      mask = False
    r_masked = np.ma.masked_array(r, mask=mask).compressed()
    data = np.ma.masked_array(dxgrid_data.grid[:,:,zi], mask=mask).compressed()
    
    radial_counts, radii = np.histogram(r_masked, bins=bins)
    radial_profile, radii = np.histogram(r_masked, weights=data, bins=bins)
    radial_mean = radial_profile/radial_counts

    averages.append(radial_mean)

  Zr = np.array(averages)

  Xr, Yr = np.meshgrid(radii[:-1], Z[0,0,:])

  return [Xr, Yr, Zr]

def radial_average(dxfile_data, dxfile_mask=None, center=(0,0), bins=None):
  """Radially average the data in a DX grid file.

  Parameters
  ----------
  dxfile_data : str
      Path to dxfile that needs radial averaging.
  dxfile_mask : str, optional
      Path to dxfile to use as a mask, by default None
  center : tuple, optional
      Center (x,y) coordinates around wich to average, by default (0,0)
  bins : int or array_like, optional
      Number of angular bins (read: resolution), by default None, which mean auto config

  Returns
  -------
  list of 3 2D arrays
      [Xr, Yr, Zr] containing x-coordinates (r), y-coordinates (z) and data, repectively.
  """
  # Load data to average
  dxgrid_data = Grid(dxfile_data)
  
  # Load mask if needed
  if dxfile_mask is not None:
    dxgrid_mask = Grid(dxfile_mask)
    dxgrid_mask = dxgrid_data * dxfile_mask
  else:
    dxgrid_mask = None
  
  if bins is None:
    bins = 33

  return _radial_average(dxgrid_data, dxgrid_mask, center, bins)


from scipy.integrate import trapz

def _cylindrical_average(dxgrid_data, radius, center=(0,0)):
  """Compute cylindrical average along entire z-axis.

  Parameters
  ----------
  dxgrid_data : {Grid}
      DX grid to radially average.
  radius : float
      Radius of integration, must be > 0.
  center : tuple, optional
      Center (x,y) coordinates around wich to average, by default (0,0).

  Returns
  -------
  list of array_like
      [z, avarage]
  """
  
  # Create meshgrid
  X,Y,Z = create_meshgrid(dxgrid_data)
  # Create mask
  R_mask = (np.hypot(X-center[0], Y-center[1]) <= radius) * 1

  # Compute integrals
  area = np.trapz(np.trapz(R_mask, x=X, axis=1), x=Y[:,0,:], axis=0)
  integral = np.trapz(
    np.trapz(dxgrid_data.grid * R_mask, x=X, axis=1), x=Y[:,0,:], axis=0
  )
  # Compute average
  average = integral / area

  zpos = Z[0,0,:]

  return [zpos, average]

  
def write_csv(filename, **data):
  """Write radially averaged grid to csv.
  
  Assumes the last element in data contains the data, others are coordinates.

  Parameters
  ----------
  filename : str
      Filename to write.
  data : dict
      (key, value) pairs for each column (name, data).
  """

  # Unravel the data
  for key, val in data.items():
    data[key] = val.ravel()

  # Index names, assumes only data in the last column
  index_names = list(data.keys())[:-1]

  # Convert it to a dataframe and save it
  df = pd.DataFrame.from_dict(data).set_index(index_names).sort_index()
  df.to_csv(filename, sep=',')


def read_csv(filename, decimals=7):
  """Read CSV with spreadsheet data.
  
  Assumes last column contains the data, others are coordinates.
  
  """
  data = pd.read_csv(filename)
  data = data.round(decimals)
  
  index_cols = len(data.columns) - 1 

  data = data.set_index(list(data.columns[0:index_cols].values)).sort_index()
  return data

def df2grid(df):
  """Convert [x,y,z] spreadsheet Dataframe to X,Y,Z 2D matrices."""
  df_unstack = df.unstack('x')
  x = df_unstack.columns.get_level_values('x').values
  y = df_unstack.index.get_level_values('y').values
  X, Y = np.meshgrid(x,y)
  Z = df_unstack.values
  return [X, Y, Z]

def smooth(X, Y, Z, delta=0.25):
  """Smooth rectangular gridded data using bivariate spline.
  
  Parameters
  ----------
  X : array_like
    (m,n) array with x-coordinates.
  Y : array_like
    (m,n) array with y-coordinates.
  Z : array_like
    (m,n) array with data
  delta : float, optional
    Grid spacing for interpolation, by default 0.25

  Returns
  -------
  list of array_like
    [Xi, Yi, Zi], interpolated coordinates
  """
  from scipy.interpolate import RectBivariateSpline as RBS
  f_int = RBS(Y[:,0].ravel(), X[0,:].ravel(), Z)
  xi, yi = [
    np.arange(X.min(), X.max() + delta, delta),
    np.arange(Y.min(), Y.max() + delta, delta)
  ]
  Xi, Yi = np.meshgrid(xi, yi)
  Zi =  f_int(yi, xi)
  return [Xi, Yi, Zi]


def mirror(X, Y, Z, invert_values=False):
    """ Mirror a given set of X and the corresponding values Z around the x=0."""
    Xmir = np.concatenate((-np.flip(X,axis=0), X[1:]), axis=0)
    Ymir = Y
    if invert_values:
        Zmir = np.concatenate((np.flip(-Z, axis=1), Z[:,1:]), axis=1)
    else:
        Zmir =  np.concatenate((np.flip(Z, axis=1), Z[:,1:]), axis=1)
    return Xmir,Ymir,Zmir
