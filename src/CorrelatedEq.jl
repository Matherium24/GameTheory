using JuMP
using HiGHS


# ============================================================================
# is_correlated_equilibrium(game, p; atol=1e-8)
#
# Theorem 8.5 & Definition 8.6: Checks whether a joint probability distribution
# p over the action space S = S₁ × S₂ satisfies all incentive-compatibility
# (obedience) constraints:
#
#   Σ_{s₋ᵢ} p(sᵢ, s₋ᵢ) [ uᵢ(sᵢ, s₋ᵢ) - uᵢ(s'ᵢ, s₋ᵢ) ] ≥ 0
#
# for every player i ∈ N and every pair of actions sᵢ, s'ᵢ ∈ Sᵢ.
# ============================================================================
function is_correlated_equilibrium(game::StrategicFormGame, p::Matrix{Float64}; atol=1e-8)
    m, n = size(game.payoffs_to_p1)

    # 1. Validate that p is a proper probability distribution
    if size(p) != (m, n)
        println("Dimension mismatch: p is $(size(p)) but the game is $(m)×$(n).")
        return false
    end

    if any(p .< -atol)
        println("Invalid distribution: p contains negative entries.")
        return false
    end

    if !isapprox(sum(p), 1.0; atol=atol)
        println("Invalid distribution: probabilities do not sum to 1 (sum = $(sum(p))).")
        return false
    end

    # 2. Check Player 1's obedience constraints (row player)
    # For each recommended row sᵢ and each alternative row s'ᵢ:
    #   Σⱼ p(sᵢ, j) * [ u₁(sᵢ, j) - u₁(s'ᵢ, j) ] ≥ 0
    for si in 1:m
        for si_prime in 1:m
            if si == si_prime
                continue
            end
            incentive = 0.0
            for j in 1:n
                incentive += p[si, j] * (game.payoffs_to_p1[si, j] - game.payoffs_to_p1[si_prime, j])
            end
            if incentive < -atol
                s_name = game.strategies[1][si]
                s_prime_name = game.strategies[1][si_prime]
                println("Player 1 violates obedience: recommended $(s_name), profitable deviation to $(s_prime_name) (deficit = $(round(incentive, digits=6))).")
                return false
            end
        end
    end

    # 3. Check Player 2's obedience constraints (column player)
    # For each recommended column sⱼ and each alternative column s'ⱼ:
    #   Σᵢ p(i, sⱼ) * [ u₂(i, sⱼ) - u₂(i, s'ⱼ) ] ≥ 0
    for sj in 1:n
        for sj_prime in 1:n
            if sj == sj_prime
                continue
            end
            incentive = 0.0
            for i in 1:m
                incentive += p[i, sj] * (game.payoffs_to_p2[i, sj] - game.payoffs_to_p2[i, sj_prime])
            end
            if incentive < -atol
                s_name = game.strategies[2][sj]
                s_prime_name = game.strategies[2][sj_prime]
                println("Player 2 violates obedience: recommended $(s_name), profitable deviation to $(s_prime_name) (deficit = $(round(incentive, digits=6))).")
                return false
            end
        end
    end

    println("All obedience constraints satisfied — p is a correlated equilibrium.")
    return true
end


# ============================================================================
# nash_to_correlated(σ₁, σ₂, game)
#
# Equation 8.10 & Theorem 8.7: Every Nash equilibrium σ* induces a product
# probability distribution over S that is guaranteed to be a correlated
# equilibrium:
#
#   p_σ(s₁, s₂) = σ₁(s₁) × σ₂(s₂)
#
# This function computes the outer product of two independent mixed strategies.
# ============================================================================
function nash_to_correlated(game::StrategicFormGame, profile::MixedStrategyProfile)
    # Convert dictionaries to ordered probability vectors aligned with game.strategies
    σ₁_vec = [get(profile.σ₁, s, 0.0) for s in game.strategies[1]]
    σ₂_vec = [get(profile.σ₂, s, 0.0) for s in game.strategies[2]]

    # Compute the outer product: p(sᵢ, sⱼ) = σ₁(sᵢ) × σ₂(sⱼ)
    p = σ₁_vec * σ₂_vec'

    println("Nash → Correlated conversion complete.")
    println("Induced joint distribution p:")
    for (i, s1) in enumerate(game.strategies[1])
        for (j, s2) in enumerate(game.strategies[2])
            if p[i, j] > 1e-10
                println("  p($(s1), $(s2)) = $(round(p[i, j], digits=6))")
            end
        end
    end

    return p
end


# ============================================================================
# compute_correlated_equilibrium(game; objective, weights)
#
# Theorem 8.9 & Remark 8.10: The set of correlated equilibria is a convex,
# compact polytope defined by:
#
#   (a) p(s) ≥ 0 for all s ∈ S            (non-negativity)
#   (b) Σ_s p(s) = 1                       (probability simplex)
#   (c) Σ_{s₋ᵢ} p(sᵢ,s₋ᵢ)[uᵢ(sᵢ,s₋ᵢ) - uᵢ(s'ᵢ,s₋ᵢ)] ≥ 0
#       for all i, sᵢ, s'ᵢ                 (obedience / incentive compatibility)
#
# Since the polytope has many points, we use Linear Programming to select a
# specific equilibrium by optimising an objective function over the polytope.
#
# Supported objectives:
#   :social_welfare  — maximise Σ_s p(s) [u₁(s) + u₂(s)]  (default)
#   :player1         — maximise Σ_s p(s) u₁(s)
#   :player2         — maximise Σ_s p(s) u₂(s)
#   :egalitarian     — maximise the minimum expected payoff across players
#   :custom          — maximise Σ_s p(s) [w₁·u₁(s) + w₂·u₂(s)] using weights
# ============================================================================
function compute_correlated_equilibrium(game::StrategicFormGame; objective::Symbol=:social_welfare, weights=nothing)
    A = game.payoffs_to_p1
    B = game.payoffs_to_p2
    m, n = size(A)

    # 1. Initialize the JuMP model with the HiGHS optimizer
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # 2. Decision variables: p[i, j] ≥ 0 for every joint action profile (i, j)
    @variable(model, p[1:m, 1:n] >= 0)

    # 3. Probability simplex constraint: all probabilities sum to 1
    @constraint(model, sum(p) == 1)

    # 4. Obedience constraints from Equation (8.9)

    # Player 1 (Row player): for each recommended row sᵢ and each deviation s'ᵢ
    for si in 1:m
        for si_prime in 1:m
            if si == si_prime
                continue
            end
            @constraint(model,
                sum(p[si, j] * (A[si, j] - A[si_prime, j]) for j in 1:n) >= 0
            )
        end
    end

    # Player 2 (Column player): for each recommended column sⱼ and each deviation s'ⱼ
    for sj in 1:n
        for sj_prime in 1:n
            if sj == sj_prime
                continue
            end
            @constraint(model,
                sum(p[i, sj] * (B[i, sj] - B[i, sj_prime]) for i in 1:m) >= 0
            )
        end
    end

    # 5. Set the LP objective based on the chosen criterion
    if objective == :social_welfare
        # Utilitarian: maximise total welfare Σ p(s)[u₁(s) + u₂(s)]
        @objective(model, Max, sum(p[i, j] * (A[i, j] + B[i, j]) for i in 1:m, j in 1:n))
        println("Objective: Maximise Social Welfare (Utilitarian)")

    elseif objective == :player1
        # Maximise Player 1's expected payoff
        @objective(model, Max, sum(p[i, j] * A[i, j] for i in 1:m, j in 1:n))
        println("Objective: Maximise Player 1's Expected Payoff")

    elseif objective == :player2
        # Maximise Player 2's expected payoff
        @objective(model, Max, sum(p[i, j] * B[i, j] for i in 1:m, j in 1:n))
        println("Objective: Maximise Player 2's Expected Payoff")

    elseif objective == :egalitarian
        # Maximin: maximise the minimum expected payoff across both players
        @variable(model, z)
        @constraint(model, sum(p[i, j] * A[i, j] for i in 1:m, j in 1:n) >= z)
        @constraint(model, sum(p[i, j] * B[i, j] for i in 1:m, j in 1:n) >= z)
        @objective(model, Max, z)
        println("Objective: Maximise Egalitarian (Maximin) Payoff")

    elseif objective == :custom
        # Weighted sum using user-provided weights
        if weights === nothing || length(weights) != 2
            error("For :custom objective, provide weights as a 2-element vector [w₁, w₂].")
        end
        w₁, w₂ = weights
        @objective(model, Max, sum(p[i, j] * (w₁ * A[i, j] + w₂ * B[i, j]) for i in 1:m, j in 1:n))
        println("Objective: Maximise Custom Weighted Sum (w₁=$(w₁), w₂=$(w₂))")

    else
        error("Unknown objective :$(objective). Use :social_welfare, :player1, :player2, :egalitarian, or :custom.")
    end

    # 6. Solve the LP
    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL
        error("The linear program did not find an optimal solution. Status: $(termination_status(model))")
    end

    # 7. Extract the optimal joint distribution
    p_vals = value.(p)

    # Clean up floating point artifacts
    for i in 1:m, j in 1:n
        p_vals[i, j] = max(0.0, p_vals[i, j])
    end

    # 8. Compute expected payoffs under the optimal distribution
    payoffs = expected_correlated_payoff(game, p_vals)

    # 9. Pretty-print the results
    println("\n--- Correlated Equilibrium (LP Solution) ---")
    println("Optimal Joint Distribution p:")
    for (i, s1) in enumerate(game.strategies[1])
        for (j, s2) in enumerate(game.strategies[2])
            if p_vals[i, j] > 1e-10
                println("  p($(s1), $(s2)) = $(round(p_vals[i, j], digits=6))")
            end
        end
    end
    println("Expected Payoffs: U₁ = $(round(payoffs[1], digits=4)), U₂ = $(round(payoffs[2], digits=4))")
    println("Social Welfare:   $(round(payoffs[1] + payoffs[2], digits=4))")

    return p_vals, payoffs
end


# ============================================================================
# expected_correlated_payoff(game, p)
#
# Computes the expected utility for each player i ∈ N under the joint
# probability distribution p:
#
#   Uᵢ(p) = Σ_s p(s) uᵢ(s)
#
# For a 2-player game, this reduces to:
#   U₁ = Σᵢ Σⱼ p(i,j) A(i,j)
#   U₂ = Σᵢ Σⱼ p(i,j) B(i,j)
# ============================================================================
function expected_correlated_payoff(game::StrategicFormGame, p::Matrix{Float64})
    A = game.payoffs_to_p1
    B = game.payoffs_to_p2

    U_1 = sum(p .* A)
    U_2 = sum(p .* B)

    return [U_1, U_2]
end
