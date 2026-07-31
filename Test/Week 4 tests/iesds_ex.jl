using GameTheory
using Test

@testset "Strategic Form - Example from Figure 4.12" begin
    # I am testing the src code for strategic 
    # form games on figure 4.12 from Ch 4

    strategies = Dict(1 => ["T", "B"], 2 => ["L", "M", "R"])

    game = StrategicFormGame(2, strategies)

    game.payoffs_to_p1 .= [
    1.0  1.0  0.0;
    0.0  0.0  2.0;
    ]

    game.payoffs_to_p2 .= [
    0.0  2.0  1.0;
    3.0  1.0  0.0;
    ]

    @testset "Game Validation" begin
        # The game should pass structural checks mathematically
        @test is_valid(game) == true
    end


    @testset "Iterated Elimination of Strictly Dominated Strategies" begin
        # Execute the IESDS solver on the game
        strat_after, p1_after, p2_after = eliminate_strictly_dominated(game)
        
        # Test 1: Did the code catch the book's error and eliminate Row M?
        # P1 should have 2 rows left, P2 should still have all 3 columns
        @test size(p1_after) == (1, 1)
        @test size(p2_after) == (1, 1)
        
        # Test 2: Did it keep the correct string names? (M should be deleted)
        @test strat_after[1] == ["T"]
        @test strat_after[2] == ["M"]
        
        # Test 3: Verify the exact final payoff values for Player 1
        @test p1_after == [
            1.0;;
        ]

        @test p2_after == [
            2.0;;
        ]
    end
end
















