module GameTheory

export ExtensiveFormGame, is_valid
export StrategicFormGame, is_valid, eliminate_strictly_dominated, pure_nash_equilibria
export StrategicFormGame, MixedStrategyProfile, in_simplex, compute_expected_payoffs,solve_zero_sum_lp, solve_indifference_full_game, check_mutation_ess

include("ExtensiveFormGame.jl")
include("StrategicFormGame.jl")
include("MixedStrategies.jl")

end
