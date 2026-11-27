# GameTheory

*Julia >= 1.10 · MIT License*

`GameTheory.jl` is a Julia package for representing and solving finite strategic-form and
extensive-form games using directed graph structures (`Graphs.jl`) and linear programming
(`JuMP.jl` with `HiGHS`).

## Implemented Solvers & Formulations

| Game Class | Solution Concept / Operation | Method & Functions |
| :--- | :--- | :--- |
| Strategic-form (2-player) | Validation, IESDS, Pure Nash Equilibria | Matrix dominance reduction and best-response intersection (`is_valid`, `eliminate_strictly_dominated`, `pure_nash_equilibria`) |
| Strategic-form (2-player) | Zero-Sum Minimax Equilibrium | Primal-dual LP via `JuMP` and `HiGHS` (`solve_zero_sum_lp`) |
| Strategic-form ($N \times N$) | Full-Support Mixed Nash Equilibrium | Linear indifference system (`solve_indifference_full_game`, `compute_expected_payoffs`, `in_simplex`) |
| Strategic-form (Symmetric) | Evolutionarily Stable Strategy (ESS) | Two-stage mutant invasion test (`check_mutation_ess`) |
| Strategic-form (2-player) | Correlated Equilibrium | Incentive-compatibility LP over the correlated polytope with utilitarian, player-specific, egalitarian, or weighted objectives (`compute_correlated_equilibrium`, `is_correlated_equilibrium`, `nash_to_correlated`, `expected_correlated_payoff`) |
| Extensive-form (Imperfect Info) | Perfect Recall & Kuhn Equivalence | Root-to-node history checks and mixed/behavior strategy conversion (`has_perfect_recall`, `enumerate_pure_strategies`, `mixed_to_behavior`, `behavior_to_mixed`, `are_equivalent`, `compute_outcome_probabilities`) |
| Extensive-form (Perfect Info) | Subgame Perfect Equilibrium (SPE) | Post-order backward induction via reverse topological sort with chance-node expectation (`has_perfect_information`, `backward_induction`, `backward_induction_path`) |

### Linear Programming Formulations

**Two-Player Zero-Sum Games (`solve_zero_sum_lp`).** For Player 1 payoff matrix $A \in \mathbb{R}^{m \times n}$, the value of the game $z$ and Player 1's minimax strategy $\sigma_1 \in \Delta(S_1)$ are obtained from

$$\max_{\sigma_1 \ge 0,\; z \in \mathbb{R}} \; z \qquad \text{subject to} \qquad \sum_{i=1}^{m} \sigma_1(i) = 1, \quad \sum_{i=1}^{m} \sigma_1(i)\, A_{ij} \ge z \quad \forall j \in \{1, \dots, n\}.$$

Player 2's optimal mixed strategy $\sigma_2 \in \Delta(S_2)$ is recovered directly from the dual shadow prices of the response constraints.

**Correlated Equilibria (`compute_correlated_equilibrium`).** A joint distribution $p \in \Delta(S_1 \times S_2)$ is selected from the correlated equilibrium polytope by solving

$$\max_{p \ge 0} \; \sum_{(s_1, s_2) \in S} c(s_1, s_2)\, p(s_1, s_2) \qquad \text{subject to} \qquad \sum_{(s_1, s_2) \in S} p(s_1, s_2) = 1,$$

$$\sum_{s_{-i} \in S_{-i}} p(s_i, s_{-i})\,\bigl[u_i(s_i, s_{-i}) - u_i(s'_i, s_{-i})\bigr] \ge 0 \qquad \forall i \in \{1, 2\},\; \forall s_i, s'_i \in S_i,$$

where $c(s_1, s_2)$ corresponds to `:social_welfare` ($u_1 + u_2$), `:player1`, `:player2`, or `:custom` weights, and `:egalitarian` replaces the objective with an epigraph variable maximizing $\min(U_1(p), U_2(p))$.

## Quickstart

### Strategic-Form Correlated Equilibrium

```julia
using GameTheory

strategies = Dict(1 => ["Swerve", "Straight"], 2 => ["Swerve", "Straight"])
payoffs_p1 = [6.0 2.0; 7.0 0.0]
payoffs_p2 = [6.0 7.0; 2.0 0.0]
game = StrategicFormGame(2, strategies, payoffs_p1, payoffs_p2)

is_valid(game)
# true

pure_nash_equilibria(game)
# Set([(2, 1), (1, 2)])

p_ce, payoffs = compute_correlated_equilibrium(game; objective = :social_welfare)
# p_ce    = [0.5 0.25; 0.25 0.0]
# payoffs = [5.25, 5.25]

is_correlated_equilibrium(game, p_ce)
# true