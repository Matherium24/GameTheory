using GameTheory
using Graphs
using Test


@testset "Extensive Form - Example 3.18" begin
    # I am testing the src code for extensive 
    # form games on example 3.18 from Ch 3 

    game = ExtensiveFormGame(14, 2)
    
    # Building the game tree:
    add_edge!(game.tree, 1, 2)  
    add_edge!(game.tree, 1, 3)     
    add_edge!(game.tree, 3, 4)  
    add_edge!(game.tree, 3, 5)      
    add_edge!(game.tree, 4, 6)  
    add_edge!(game.tree, 4, 7)      
    add_edge!(game.tree, 7, 8)  
    add_edge!(game.tree, 7, 9)      
    add_edge!(game.tree, 5, 10) 
    add_edge!(game.tree, 5, 11)     
    add_edge!(game.tree, 11, 12) 
    add_edge!(game.tree, 11, 13) 
    add_edge!(game.tree, 11, 14) 
    
    game.player_at_node[1] = 1  
    game.player_at_node[3] = 0  
    game.player_at_node[4] = 2  
    game.player_at_node[5] = 1  
    game.player_at_node[7] = 0  
    game.player_at_node[11] = 0     
    
    # Replaced 'chance_probs' with 'prob_of_chance' to match your struct!
    game.prob_of_chance[3] = [1/2, 1/2]
    game.prob_of_chance[7] = [1/3, 2/3]
    game.prob_of_chance[11] = [1/4, 1/2, 1/4]    
    
    # Replaced 'payoffs' with 'payoff'
    game.payoff[2] = [0.0, 0.0]
    game.payoff[6] = [2.0, 0.0]
    game.payoff[8] = [5.0, -1.0]
    game.payoff[9] = [-2.0, 5.0]
    game.payoff[10] = [1.0, 1.0]
    game.payoff[12] = [0.0, 2.0]
    game.payoff[13] = [-1.0, 1.0]
    game.payoff[14] = [1.0, 1.0]

    # Replaced 'information_sets' with 'information_set'
    push!(game.information_set[1], Set([1]))
    push!(game.information_set[1], Set([5]))
    push!(game.information_set[2], Set([4]))

    # Running tests to verify the structure:
    @test nv(game.tree) == 14
    @test ne(game.tree) == 13
    @test game.player_at_node[3] == 0
    @test sum(game.prob_of_chance[11]) ≈ 1.0
    @test game.payoff[8] == [5.0, -1.0]
end