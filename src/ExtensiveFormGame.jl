using Graphs

struct ExtensiveFormGame
    tree::DiGraph   # (V, E, x^0)
    root::Int   #x^0
    num_players::Int    #N
    player_at_node::Dict{Int, Int}  #(V_i)
    prob_of_chance::Dict{Int, Vector{Float64}}  #(p_x)
    information_set::Dict{Int, Vector{Set{Int}}}    #(U_i)
    payoff::Dict{Int, Vector{Float64}}  #u
end

function ExtensiveFormGame(num_nodes::Int, num_players::Int, root::Int=1)
    tree = DiGraph(num_nodes)
    player_at_node = Dict{Int, Int}() #(V_i)
    prob_of_chance = Dict{Int, Vector{Float64}}() #(p_x)
    payoff = Dict{Int, Vector{Float64}}() #u
    information_set = Dict{Int, Vector{Set{Int}}}() #(U_i)
    for i in 1:num_players
        information_set[i] = Vector{Set{Int}}()
    end

    return ExtensiveFormGame(
        tree, 
        root, 
        num_players, 
        player_at_node, 
        prob_of_chance, 
        information_set, 
        payoff
    )
end

#A function that checks if the constructed game tree mathematically adheres to the definitions 
#of extensive-form games established in Chapter 3.


function is_valid(game::ExtensiveFormGame)
    #First to check if all terminal leaves have payoffs
    for v in vertices(game.tree)
        if outdegree(game.tree, v) == 0
            if !haskey(game.payoff, v)
                println("Error: Terminal node $v is missing a payoff vector.")
                return false
            end
            if length(game.payoff[v]) != game.num_players
                println("Error: Payoff at terminal node $v must contain exactly $(game.num_players) values.")
                return false
            end
        end
    end

    #Second, to check if chance probabilities sum up to 1
    for (node, probs) in game.prob_of_chance #Loops only through vertices that have chance probabilities
        if !isapprox(sum(probs), 1.0; atol = 1e-5) #Using isapprox as Julia considers 0.99999 != 1
            println("Error: Probabilities at chance node $node sum to $(sum(probs)), not 1.0.")
            return false
        end

        #Checking if number of probabilities matches number of outgoing edges
        edges_out = outdegree(game.tree, node)
        if length(probs) != edges_out
            println("Error: Chance node $node has $edges_out outgoing edges, but $(length(probs)) probabilities were given.")
            return false
        end
    end


    #Third is to check information sets contain only nodes 
    #that have the exact same number of outgoing edges
    for (player_id, info_sets) in game.information_set
        for iset in info_sets
            if !isempty(iset)
                # Get the number of actions at the very first node in this set
                first_node = first(iset)
                required_actions = outdegree(game.tree, first_node)
                
                # Check every other node in the set against it
                for node in iset
                    if outdegree(game.tree, node) != required_actions
                        println("Error: Info set for Player $player_id contains nodes with different numbers of available actions.")
                        return false
                    end
                end
            end
        end
    end

    # If the game survived all checks then we return true
    return true
end


#The function that prints the game tree in the terminal:
#function print_tree(game::ExtensiveFormGame, node::Int=game.root, prefix::String="", is_last::Bool=true, edge_prob::Float64=NaN)
#    # 1. Format the probability (if the parent was Nature)
#    prob_str = isnan(edge_prob) ? "" : "[p=$(round(edge_prob, digits=2))] "
#    
#    # 2. Format the label (Player, Nature, or Terminal)
#    if outdegree(game.tree, node) == 0
#        label = "Node $node: Terminal -> Payoff: $(game.payoff[node])"
#    else
#        owner = get(game.player_at_node, node, -1)
#        label = owner == 0 ? "Node $node: Nature" : "Node $node: Player $owner"
#    end
#
#    # 3. Print the current node with the correct branch markers
#    marker = node == game.root ? "" : (is_last ? "└── " : "├── ")
#    println(prefix * marker * prob_str * label)
#
#    # 4. Find children and recurse!
#    children = outneighbors(game.tree, node)
#    new_prefix = prefix * (node == game.root ? "" : (is_last ? "    " : "│   "))
#    
#    for (i, child) in enumerate(children)
#        child_is_last = (i == length(children))
#        child_prob = NaN
#        # If this node belongs to Nature, grab the probability for the specific edge
#        if get(game.player_at_node, node, -1) == 0 && haskey(game.prob_of_chance, node)
#            child_prob = game.prob_of_chance[node][i]
#        end
#        print_tree(game, child, new_prefix, child_is_last, child_prob)
#    end
#end
# -------------