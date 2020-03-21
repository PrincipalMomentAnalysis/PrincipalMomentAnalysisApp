using PrincipalMomentAnalysisApp
using Test

import PrincipalMomentAnalysisApp: JobGraph, process_thread

@testset "PrincipalMomentAnalysisApp" begin
    include("test_content.jl")
    include("test_app.jl")
end
