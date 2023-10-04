# Datastore for H5 / HDF5 timeseries files

[![View HDF5 custom file datastore for timeseries in MATLAB on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/64919-hdf5-custom-file-datastore-for-timeseries-in-matlab)
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=mathworks/hdf5-datastore&file=Demo_H5Datastore.mlx)

MATLAB Extensible Datastore for H5 / HDF5 timeseries files

A MATLAB class and example implementing a custom file datastore. This component allows you to read time series data stored as simple variables within Hierarchical Data Format 5 (H5 / HDF5). The data may be read from a series of individual files, and assumes that every file in the set contains the same variable names you want to read with the same attributes. The reading takes place by chunks of rows of the data matrices.

More information on MATLAB Datastore can be found here:
https://www.mathworks.com/help/matlab/datastore.html
