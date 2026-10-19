module GameTheory

export ExtensiveFormGame, is_valid
export StrategicFormGame, is_valid, eliminate_strictly_dominated, pure_nash_equilibria
export StrategicFormGame, MixedStrategyProfile, in_simplex, compute_expected_payoffs,solve_zero_sum_lp, solve_indifference_full_game, check_mutation_ess
export BehaviorStrategyProfile, path_from_root, find_infoset_index, get_action_index, player_history, enumerate_pure_strategies, build_strategy!, has_perfect_recall, mixed_to_behavior, behavior_to_mixed, compute_outcome_probabilities, are_equivalent 
export has_perfect_information, backward_induction, backward_induction_path
export is_correlated_equilibrium, nash_to_correlated, compute_correlated_equilibrium, expected_correlated_payoff

include("ExtensiveFormGame.jl")
include("StrategicFormGame.jl")
include("MixedStrategies.jl")
include("BehaviourStrategies.jl")
include("Refinements.jl")
include("CorrelatedEq.jl")

end
