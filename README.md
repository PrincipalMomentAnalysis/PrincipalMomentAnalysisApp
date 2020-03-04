# Principal Moment Analysis App

[![Build Status](https://travis-ci.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl.svg?branch=master)](https://travis-ci.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl?svg=true)](https://ci.appveyor.com/project/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp-jl)
[![Codecov](https://codecov.io/gh/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl)
[![Coveralls](https://coveralls.io/repos/github/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl/badge.svg?branch=master)](https://coveralls.io/github/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl?branch=master)

The Principal Moment Analysis App is a simple GUI Application for exploring data sets using Principal Moment Analysis.
More information coming soon.

See also:

* [Principal Moment Analysis home page](https://principalmomentanalysis.github.io/).
* [PrincipalMomentAnalysis.jl](https://principalmomentanalysis.github.io/PrincipalMomentAnalysis).

## Installation
In a few days, PrincipalMomentAnalysisApp.jl will be registered. Until then, you can install it with
```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/PrincipalMomentAnalysis/PrincipalMomentAnalysisApp.jl.git"))
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
