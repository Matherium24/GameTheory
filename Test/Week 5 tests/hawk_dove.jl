using Test
using GameTheory

@testset "Evolutionary Game Theory - Coordination Variant" begin
    # 1. Define the strategy space
    strategies = Dict(
        1 => ["Dove", "Hawk"], 
        2 => ["Dove", "Hawk"]
    )

    # 2. Instantiate the game
    game = StrategicFormGame(2, strategies)

    # 3. Populate the payoff matrices based on image_aec863.png
    # Player 1's payoffs (Row player)
    game.payoffs_to_p1 .= [
        4.0  1.0;
        3.0  2.0
    ]
    
    # Player 2's payoffs (Column player)
    # Because it is a symmetric game, B = A^T
    game.payoffs_to_p2 .= [
        4.0  3.0;
        1.0  2.0
    ]

    @testset "Indifference Principle Solver" begin
        println("\nRunning Indifference Principle Solver...")
        val_x, val_y = solve_indifference_full_game(game)
        
        # Test 1: Did the solver find the [0.5, 0.5] equilibrium for Player 1?
        @test isapprox(val_x[1], 0.5, atol=1e-4) # Dove
        @test isapprox(val_x[2], 0.5, atol=1e-4) # Hawk
        
        # Test 2: Did the solver find the [0.5, 0.5] equilibrium for Player 2?
        @test isapprox(val_y[1], 0.5, atol=1e-4)
        @test isapprox(val_y[2], 0.5, atol=1e-4)
    end

    @testset "ESS Mutation Check" begin
        println("\nRunning ESS Mutation Check...")
        
        # Define the established population (x*) and the mutant (x)
        x_star = Dict("Dove" => 0.5, "Hawk" => 0.5)
        x_mutant = Dict("Dove" => 1.0, "Hawk" => 0.0)
        
        # Run the ESS checker
        is_repelled = check_mutation_ess(game, x_star, x_mutant)
        
        # Test 3: The mutation should successfully INVADE (Condition 2 fails). 
        # Therefore, the function should return false.
        @test is_repelled == false
    end
end