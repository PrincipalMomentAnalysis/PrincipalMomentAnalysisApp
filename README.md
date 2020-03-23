# Principal Moment Analysis App

[![Build Status](https://travis-ci.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl.svg?branch=master)](https://travis-ci.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl?svg=true)](https://ci.appveyor.com/project/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp-jl)
[![Codecov](https://codecov.io/gh/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl)
[![Coveralls](https://coveralls.io/repos/github/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl/badge.svg?branch=master)](https://coveralls.io/github/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl?branch=master)

The Principal Moment Analysis App is a simple GUI Application for exploring data sets using Principal Moment Analysis.
See below for usage instructions.

For more information about Principal Moment Analysis, please refer to:

* [Principal Moment Analysis home page](https://principalmomentanalysis.github.io/).
* [PrincipalMomentAnalysis.jl](https://principalmomentanalysis.github.io/PrincipalMomentAnalysis.jl).

If you want to cite our work, please use:

> [Fontes, M., & Henningsson, R. (2020). Principal Moment Analysis. arXiv arXiv:2003.04208.](https://arxiv.org/abs/2003.04208)

## Installation
To install PrincipalMomentAnalysisApp.jl, start Julia and type:
```julia
using Pkg
Pkg.add("PrincipalMomentAnalysisApp")
```

## Running the App

*Option 1*

Start Julia and run:
```julia
using PrincipalMomentAnalysisApp
pmaapp()
```

*Option 2*

Run the following command from a terminal/command prompt:
```
julia -e "using PrincipalMomentAnalysisApp; pmaapp()"
```
Note that this requires julia to be in the PATH.

## Using the App

<img src="https://github.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl/blob/master/docs/src/images/app1.png" alt="App before loading a file" title="App before loading a file" width="341" height="563">&nbsp;&nbsp;<img src="https://github.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl/blob/master/docs/src/images/app2.png" alt="App after loading a file" title="App after loading a file" width="341" height="563">

### Loading a file

PrincipalMomentAnalysisApp can load *.csv* (comma-separated values) or *.tsv* (tab-separated values) files, *.txt* and other extensions are treated as *.tsv*. 
You can choose whether samples are described by rows or columns.

Input file example:

| Sample ID | Sample Annotation 1 | Sample Annotation 2 | ... | Variable 1 | Variable 2 | ... |
| --------- | ------------------- | ------------------- | --- | ---------- | ---------- | --- |
| A | Group1 | 0.1 | ... | 0.0 | 0.5 | ... |
| B | Group1 | 0.4 | ... | 1.0 | 0.2 | ... |
| C | Group2 | 2.0 | ... | 0.3 | 0.8 | ... |

After loading a file, you need to choose the last sample annotation in the dropdown list. This is **important**, since the rest of the columns will be used as variables.

### Normalization

* *None*: The data matrix is not modified.
* *Mean=0*: Variables are centered.
* *Mean=0,Std=1*: Variables are centered and their standard deviations are normalized to 1.

### Dimension Reduction

In addition to **PMA** (Principal Moment Analysis), you can also choose **PCA** (Principal Component Analysis) for reference. **PCA** is a special case of **PMA** with point masses for each sample.

**PMA** is a flexible method where we can use our knowledge about the data to improve the dimension reduction.
In the GUI, you can choose between four different methods for how to create the simplices that represent our data set.

* *Sample Annotation*: All samples sharing the same value of the chosen *sample annotation* will be connected to form a simplex. The total weight of each simplex is equal to the number of samples forming the simplex.
* *Time Series*: First the samples are divided into groups by the chosen *sample annotation*. Then simplices are formed by connecting each sample to the previous and next sample according to the *time annotation*. (If there are ties, all samples at a timepoint will be connected to all samples at the previous/next timepoints.)
* *Nearest Neighbors*: For each sample, a simplex is created by connecting to the chosen number of nearest neighbors. You can also chose to connect a sample to neighbours within a distance threshold (normalized such that a distance of 1 is the distance of the samples furthest away from each other). To reduce noise, distances between samples are computed after reducing the dimension to 50 by PCA.
* *Nearest Neighbors within groups*: As for *Nearest Neighbors*, but samples are only connected if they share the same value of the chosen *sample annotation*.


### Plotting

The plotting options allow you to visualize the samples and the simplices after dimension reduction. (If you chose **PCA** above, the simplices will still be visualized, but the dimension reduction will be computed by PCA.)

* Axes: You can choose which Principal Moment Axis (PMA) to display for the *x*, *y*, and *z* axes respectively. This is useful for exploring more than the first 3 dimensions.
* Plot size: Control the width/height of the plotting area.
* Color: Decide which *sample annotation* to use for coloring the samples. For numerical data, a continuous color scale will be used.
* Points: Enable/disable drawing of the sample points and choose their size.
* Lines: Enable/disable drawing of the simplex edges and choose line width.
* Triangles: Enable/disable drawing of the simplex facets and choose opacity.

Press the "Show Plot" button to open the plot in a new window.


### Export Principal Moment Axes

The PMAs, giving you the low-dimensional representations of variables/samples, can be exported to text files. The exported files are tab-separated (or comma-separated if the file extension is *.csv*).
When exporing a single PMA, you can also choose the sorting.
