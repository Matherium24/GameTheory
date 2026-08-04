using Test
using GameTheory

@testset "Evolutionary Game Theory - Modified RPS" begin
    # 1. Define the strategy space
    strategies = Dict(
        1 => ["Rock", "Paper", "Scissors"], 
        2 => ["Rock", "Paper", "Scissors"]
    )

    # 2. Instantiate the game
    game = StrategicFormGame(2, strategies)

    # 3. Populate the payoff matrices based on image_ae5044.png
    # Player 1's payoffs (Row player)
    game.payoffs_to_p1 .= [
        (2.0/3.0)  0.0        1.0;
        1.0        (2.0/3.0)  0.0;
        0.0        1.0        (2.0/3.0)
    ]
    
    # Player 2's payoffs (Column player)
    game.payoffs_to_p2 .= [
        (2.0/3.0)  1.0        0.0;
        0.0        (2.0/3.0)  1.0;
        1.0        0.0        (2.0/3.0)
    ]

    @testset "Indifference Principle Solver (3x3)" begin
        println("\nRunning Indifference Principle Solver...")
        val_x, val_y = solve_indifference_full_game(game)
        
        # Test 1: Did the solver find the [1/3, 1/3, 1/3] equilibrium for Player 1?
        @test isapprox(val_x[1], 1.0/3.0, atol=1e-4) # Rock
        @test isapprox(val_x[2], 1.0/3.0, atol=1e-4) # Paper
        @test isapprox(val_x[3], 1.0/3.0, atol=1e-4) # Scissors
        
        # Test 2: Did the solver find the [1/3, 1/3, 1/3] equilibrium for Player 2?
        @test isapprox(val_y[1], 1.0/3.0, atol=1e-4)
        @test isapprox(val_y[2], 1.0/3.0, atol=1e-4)
        @test isapprox(val_y[3], 1.0/3.0, atol=1e-4)
    end

    @testset "ESS Mutation Check (Pure Rock Invades)" begin
        println("\nRunning ESS Mutation Check...")
        
        # Define the established population (x*) and the mutant (x)
        x_star = Dict("Rock" => 1.0/3.0, "Paper" => 1.0/3.0, "Scissors" => 1.0/3.0)
        x_mutant = Dict("Rock" => 1.0, "Paper" => 0.0, "Scissors" => 0.0)
        
        # Run the ESS checker
        is_repelled = check_mutation_ess(game, x_star, x_mutant)
        
        # Test 3: The mutation should successfully INVADE.
        # Condition 1 Ties: u(x, x*) == u(x*, x*) == 5/9
        # Condition 2 Fails: u(x, x) = 2/3, which is NOT strictly less than u(x*, x) = 5/9. 
        # Therefore, the function should return false.
        @test is_repelled == false
    end
end