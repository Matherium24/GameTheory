using LinearAlgebra
using JuMP
using HiGHS


struct StrategicFormGame
    num_players::Int
    strategies::Dict{Int, Vector{String}}
    payoffs_to_p1::Matrix{Float64}
    payoffs_to_p2::Matrix{Float64}
end

function StrategicFormGame(num_players::Int, strategies::Dict{Int, Vector{String}})
    if num_players != 2
        error("The current system only allows for 2-player games.")
    end

    m = length(strategies[1])
    n = length(strategies[2])

    payoffs_to_p1 = zeros(Float64, m, n)
    payoffs_to_p2 = zeros(Float64, m, n)

    return StrategicFormGame(num_players, strategies, payoffs_to_p1, payoffs_to_p2)
end

struct MixedStrategyProfile
    σ₁::Dict{String, Float64}
    σ₂::Dict{String, Float64}
end

# Helper function to check if a strategy belongs to the simplex Δ(S_i)
function in_simplex(sigma::Dict{String, Float64})
    probs = values(sigma)
    return all(p -> p >= 0.0, probs) && isapprox(sum(probs), 1.0; atol=1e-5)
end

# Function to compute the multilinear expected payoffs U_i(σ)
function compute_expected_payoffs(game::StrategicFormGame, profile::MixedStrategyProfile)
    if !in_simplex(profile.σ₁) || !in_simplex(profile.σ₂)
        error("Invalid mixed strategy: Probabilities must be non-negative and sum to 1.")
    end

    σ₁_vec = [get(profile.σ₁, s, 0.0) for s in game.strategies[1]]
    σ₂_vec = [get(profile.σ₂, s, 0.0) for s in game.strategies[2]]

    U_1 = dot(σ₁_vec, game.payoffs_to_p1 * σ₂_vec)
    U_2 = dot(σ₁_vec, game.payoffs_to_p2 * σ₂_vec)

    return U_1, U_2
end


function solve_zero_sum_lp(game::StrategicFormGame)
    # Extract Player 1's payoff matrix (A) and its dimensions
    A = game.payoffs_to_p1
    m, n = size(A)
    # Initialize the JuMP model with the HiGHS optimizer
    model = Model(HiGHS.Optimizer)
    set_silent(model) # Suppresses the solver's console output
    # σ₁ represents the probability distribution over Player 1's pure strategies
    # Indexed by 1:m to align cleanly with the rows of matrix A
    @variable(model, σ₁[1:m] >= 0)
    # z represents the guaranteed expected payoff (the value of the game)
    @variable(model, z)
    # Theorem 5.22: Z_P := max z
    @objective(model, Max, z)
    # Constraint 1: The probabilities must sum to 1
    @constraint(model, sum(σ₁) == 1)
    # Constraint 2: The expected payoff against every pure strategy of Player II must be >= z
    # Name the constraint container p2_responses to extract shadow prices later
    @constraint(model, p2_responses[j=1:n], sum(σ₁[i] * A[i, j] for i in 1:m) >= z)
    # Optimisation step and Extracting the results
    optimize!(model)
    if termination_status(model) != MOI.OPTIMAL
        error("The linear program did not find an optimal solution.")
    end
    # Extract the value of the game Zₚ
    value_of_game = value(z)
    println("Value of the game in mixed strategies (Zₚ): ", round(value_of_game, digits=4))
    # Extract Player 1's optimal mixed strategy vector
    σ₁_vals = value.(σ₁)
    computed_σ₁ = Dict{String, Float64}()
    for (i, strategy) in enumerate(game.strategies[1])
        # Clean up floating point inaccuracies (e.g., -0.00000000001 to 0.0)
        computed_σ₁[strategy] = max(0.0, σ₁_vals[i])
    end
    # Extract Player 2's optimal mixed strategy vector
    # By linear programming duality, Player 2's probabilities correspond to 
    # the shadow prices (dual values) of the response constraints we just defined.
    σ₂_vals = shadow_price.(p2_responses)
    computed_σ₂ = Dict{String, Float64}()
    for (j, strategy) in enumerate(game.strategies[2])
        computed_σ₂[strategy] = max(0.0, abs(σ₂_vals[j]))
    end

    return MixedStrategyProfile(computed_σ₁, computed_σ₂)
end


function solve_indifference_full_game(game::StrategicFormGame)
    A = game.payoffs_to_p1
    B = game.payoffs_to_p2
    
    m, n = size(A)
    if m != n
        error("Indifference principle solver currently expects a square NxN game.")
    end
    
    N = m
    
    # 1. Solve for probability of Player 2's strategy (column vector y) using Matrix A:

    M_y = zeros(Float64, N, N)
    
    # Fill the first N-1 rows with the differences between consecutive payoff rows
    for i in 1:(N-1)
        M_y[i, :] = A[i, :] - A[i+1, :]
    end
    
    # Fill the last row with 1s to enforce the probabilities sum to 1
    M_y[N, :] = ones(N)
    
    # The right-hand side vector: 0s for the differences, 1 for the sum
    b = zeros(Float64, N)
    b[N] = 1.0
    
    # Solve the linear system M_y * y = b using matrix division
    val_y = M_y \ b

    # 2. Solve for probability of Player 1's strategy (column vector x) using Matrix B:
    
    M_x = zeros(Float64, N, N)
    
    # Player 2 compares columns, which are the rows of B transposed
    B_T = transpose(B)
    for i in 1:(N-1)
        M_x[i, :] = B_T[i, :] - B_T[i+1, :]
    end
    M_x[N, :] = ones(N)
    
    # Solve the linear system M_x * x = b
    val_x = M_x \ b

    # 3. Output the Results

    println("Indifference Principle Solution ($(N)x$(N)):")
    # Rounding for cleaner terminal output
    println("The probability vector P1 plays is, x = ", round.(val_x, digits=4))
    println("The probability vector P2 plays is, y = ", round.(val_y, digits=4))
    
    return val_x, val_y
end


function check_mutation_ess(game::StrategicFormGame, x_star::Dict{String, Float64}, x_mutant::Dict{String, Float64})
    
    # 1. Structural Guardrail: Check for Game Symmetry

    strategies_match = game.strategies[1] == game.strategies[2]
    payoffs_symmetric = isapprox(game.payoffs_to_p1, transpose(game.payoffs_to_p2), atol=1e-5)
    
    if !strategies_match || !payoffs_symmetric
        error("ESS evaluation failed: The provided game is not symmetric. Both the strategy spaces (S₁ = S₂) and payoff matrices (A = Bᵀ) must match.")
    end

    A = game.payoffs_to_p1
    
    # Convert dictionaries to ordered probability vectors
    star_vec = [get(x_star, s, 0.0) for s in game.strategies[1]]
    mutant_vec = [get(x_mutant, s, 0.0) for s in game.strategies[1]]
    
    # 2. Compute Expected Payoffs: u(p, q) = p^T * A * q

    u_star_star     = dot(star_vec, A * star_vec)
    u_mutant_star   = dot(mutant_vec, A * star_vec)
    
    u_star_mutant   = dot(star_vec, A * mutant_vec)
    u_mutant_mutant = dot(mutant_vec, A * mutant_vec)
    
    # 3. Evaluate Theorem 5.52 Conditions

    println("--- ESS Mutation Check ---")
    println("u(x*, x*) = ", round(u_star_star, digits=4))
    println("u(x, x*)  = ", round(u_mutant_star, digits=4))
    
    # Condition 1: Strict advantage against the established population
    # u_1(x, x*) < u_1(x*, x*)
    if u_mutant_star < u_star_star - 1e-5
        println("Result: Mutation REPELLED (Condition 1).")
        println("Reason: The established population earns a strictly higher payoff against itself than the mutant does.")
        return true
        
    # Condition 2: Weak Nash tie, falling back to mutant-vs-mutant interaction
    # u_1(x, x*) == u_1(x*, x*) AND u_1(x, x) < u_1(x*, x)
    elseif isapprox(u_mutant_star, u_star_star, atol=1e-5)
        println("\nCondition 1 Tied. Checking Condition 2...")
        println("u(x*, x) = ", round(u_star_mutant, digits=4))
        println("u(x, x)  = ", round(u_mutant_mutant, digits=4))
        
        if u_mutant_mutant < u_star_mutant - 1e-5
            println("Result: Mutation REPELLED (Condition 2).")
            println("Reason: The mutant earns less against itself than the population earns against the mutant.")
            return true
        else
            println("Result: Mutation INVADES (Condition 2 Failed).")
            println("Reason: The mutant thrives when interacting with other mutants.")
            return false
        end
        
    # Failure State: The established strategy wasn't a Nash equilibrium
    # u_1(x, x*) > u_1(x*, x*)
    else
        println("Result: Mutation INVADES (Not a Nash Equilibrium).")
        println("Reason: The mutant strictly dominates the population in the primary environment.")
        return false
    end
end