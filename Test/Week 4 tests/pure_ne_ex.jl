using GameTheory
using Test

@testset "Strategic Form - Example from Figure 4.22" begin
    # I am testing the src code for strategic 
    # form games on figure 4.22 from Ch 4

    strategies = Dict(1 => ["T", "M", "B"], 2 => ["L", "C", "R"])

    game = StrategicFormGame(2, strategies)

    game.payoffs_to_p1 .= [
    0.0  6.0  4.0;
    6.0  0.0  4.0;
    3.0  3.0  5.0;
    ]

    game.payoffs_to_p2 .= [
    6.0  0.0  3.0;
    0.0  6.0  3.0;
    3.0  3.0  5.0;
    ]

    @testset "Game Validation" begin
        # The game should pass structural checks mathematically
        @test is_valid(game) == true
    end


    @testset "Pure Nash Equilibrium Solver" begin
        
        # The function only returns the final Set of equilibria
        nash_equilibria = pure_nash_equilibria(game)
        
        # We should get row 3, column 3 as the only pure Nash Equilibrium
        @test nash_equilibria == Set([(3, 3)])
        
    end
end