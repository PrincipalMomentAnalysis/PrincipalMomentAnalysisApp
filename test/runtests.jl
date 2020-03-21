using PrincipalMomentAnalysisApp
using Test
using PrincipalMomentAnalysis
using LinearAlgebra
using DataFrames
using CSV

import PrincipalMomentAnalysisApp: JobGraph, process_thread, process_step
using PrincipalMomentAnalysisApp.Schedulers

include("utils.jl")

@testset "PrincipalMomentAnalysisApp" begin
    include("test_content.jl")
    include("test_app.jl")
end
