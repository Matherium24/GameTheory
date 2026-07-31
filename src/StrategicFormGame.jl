struct StrategicFormGame
    num_players::Int
    strategies::Dict{Int, Vector{String}}
    payoffs_to_p1::Matrix{Float64}
    payoffs_to_p2::Matrix{Float64}
    
    #Defining a function to store the payoff values
end

function StrategicFormGame(num_players, strategies)
    if num_players != 2
        error("The current system only allows for 2 player games")
    end

    m = length(strategies[1])
    n = length(strategies[2])

    payoffs_to_p1 = Matrix{Float64}(undef, m, n)
    payoffs_to_p2 = Matrix{Float64}(undef, m, n)

    return StrategicFormGame(
        num_players, 
        strategies, 
        payoffs_to_p1, 
        payoffs_to_p2)
end


#Defining a function that checks if the constructed strategic form game mathematically adheres to the definitions 
#of strategic-form games established in Chapter 4.
function is_valid(game::StrategicFormGame)
    #First to check if dimensions of the payoff matrices match the number of strategies defined for each player.
    if size(game.payoffs_to_p1, 1) != length(game.strategies[1]) || size(game.payoffs_to_p1, 2) != length(game.strategies[2])
        println("The dimensions of the payoff matrix of player 1 do not match the number of strategies defined for each player")
        return false
    end
    if size(game.payoffs_to_p2, 1) != length(game.strategies[1]) || size(game.payoffs_to_p2, 2) != length(game.strategies[2])
        println("The dimensions of the payoff matrix of player 2 do not match the number of strategies defined for each player")
        return false
    end

    #Second to ensure that the strategy sets are non empty.
    if isempty(game.strategies[1])
        println("The strategy set of player 1 is empty")
        return false
    end
    if isempty(game.strategies[2])
        println("The strategy set of player 2 is empty")
        return false
    end
    # If the game survived all checks then we return true
    return true
end

#Defining a function to perform iterated elimination of strictly dominated strategies
function eliminate_strictly_dominated(game::StrategicFormGame)
    # 1. Create local copies so we don't alter the original game's memory
    p1_after_IESDS = copy(game.payoffs_to_p1)
    p2_after_IESDS = copy(game.payoffs_to_p2)
    # Use deepcopy for the dictionary because it contains arrays inside it
    strat_after_IESDS = deepcopy(game.strategies) 
    
    eliminated_in_this_pass = true
    
    # The outer loop ensures the "Iterated" part of IESDS
    while eliminated_in_this_pass
        eliminated_in_this_pass = false
        
        # 1. Check for Strictly Dominated Rows (Player 1)
        m = size(p1_after_IESDS, 1)
        for i in 1:m
            for j in 1:m
                # Ensure we don't compare a row to itself, and check for strict domination
                if i != j && all(p1_after_IESDS[i, :] .> p1_after_IESDS[j, :])
                    
                    # Row i strictly dominates Row j. Delete Row j from BOTH local matrices.
                    p1_after_IESDS = p1_after_IESDS[setdiff(1:m, j), :]
                    p2_after_IESDS = p2_after_IESDS[setdiff(1:m, j), :]
                    
                    # Delete the strategy name from the local dictionary
                    deleteat!(strat_after_IESDS[1], j)
                    
                    # Flag that we changed the matrix, break the loops, and start over
                    eliminated_in_this_pass = true
                    break 
                end
            end
            if eliminated_in_this_pass
                break # Break outer row loop to restart the while loop safely
            end
        end
        
        # If we just deleted a row, restart the while loop immediately 
        if eliminated_in_this_pass
            continue 
        end
        
        # 2. Check for Strictly Dominated Columns (Player 2) 
        n = size(p2_after_IESDS, 2)
        for i in 1:n
            for j in 1:n
                # Player 2 looks at p2_after_IESDS, and compares columns
                if i != j && all(p2_after_IESDS[:, i] .> p2_after_IESDS[:, j])
                    
                    # Col i strictly dominates Col j. Delete Col j from BOTH local matrices.
                    p1_after_IESDS = p1_after_IESDS[:, setdiff(1:n, j)]
                    p2_after_IESDS = p2_after_IESDS[:, setdiff(1:n, j)]
                    
                    # Delete the strategy name from the local dictionary
                    deleteat!(strat_after_IESDS[2], j)
                    
                    eliminated_in_this_pass = true
                    break 
                end
            end
            if eliminated_in_this_pass
                break # Break outer column loop to restart the while loop safely
            end
        end
    end
    
    println("IESDS complete")
    
    # Return the newly computed variables
    return strat_after_IESDS, p1_after_IESDS, p2_after_IESDS
end



#Defining a function to find out the Pure Nash Equilibrium
function pure_nash_equilibria(game::StrategicFormGame)
    #Define Sets to store the (row, column) coordinates of best responses
    best_responses_p1 = Set{Tuple{Int, Int}}()
    best_responses_p2 = Set{Tuple{Int, Int}}()

    m = size(game.payoffs_to_p1, 1)
    n = size(game.payoffs_to_p1, 2)

    # Player 1 (Rows): Find the best response in each column
    for j in 1:n
        max_val = maximum(game.payoffs_to_p1[:, j])
        
        for i in 1:m
            if game.payoffs_to_p1[i, j] == max_val
                push!(best_responses_p1, (i, j))
            end
        end
    end

    # Player 2 (Columns): Find the best response in each row
    for i in 1:m
        max_val = maximum(game.payoffs_to_p2[i, :])
        
        for j in 1:n
            if game.payoffs_to_p2[i, j] == max_val
                push!(best_responses_p2, (i, j))
            end
        end
    end

    # 4. The Nash Equilibria are simply the intersection of both sets!
    nash_equilibria = intersect(best_responses_p1, best_responses_p2)

    # --- NEW: Formatted Output for Humans ---
    println("\n Pure Nash Equilibria: \n")
    if isempty(nash_equilibria)
        println("No pure-strategy Nash Equilibria found in this game.")
    else
        # Loop through every equilibrium coordinate pair found
        for (i, j) in nash_equilibria
            # Extract the string names using the indices
            s1 = game.strategies[1][i]
            s2 = game.strategies[2][j]
            
            # Extract the actual payoff values
            p1_val = game.payoffs_to_p1[i, j]
            p2_val = game.payoffs_to_p2[i, j]
            
            println("Strategy Profile: ($s1, $s2) with Payoffs: ($p1_val, $p2_val)")
        end
    end
    
    return nash_equilibria
end








































