using Pkg
Pkg.instantiate()

# Paths are relative to the project root, not the script directory
const PROJECT_ROOT = dirname(@__DIR__)

include(joinpath(PROJECT_ROOT, "Test", "Week 8 tests", "chicken.jl"))
include(joinpath(PROJECT_ROOT, "Test", "Week 8 tests", "battle_of_the_sexes.jl"))
include(joinpath(PROJECT_ROOT, "Test", "Week 8 tests", "asymmetric_coordination.jl"))
