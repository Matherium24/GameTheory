using Graphs

struct BehaviorStrategyProfile
    player::Int
    distributions::Dict{Int, Vector{Float64}}  # distributions[u][k] = probability of choosing action k at info set u.
end

# ========================================================================================
# Helper Functions:
# ========================================================================================

#Finding the unique path from the root to any vertex in the directed game tree.
#Returns a Vector{Int} of vertices from root to target (inclusive on both ends).
function path_from_root(game::ExtensiveFormGame, target::Int)
    path = [target]
    current = target
    while current != game.root
        parents = inneighbors(game.tree, current)
        if isempty(parents)
            error("Vertex $current has no parent and is not the root. The tree may be disconnected.")
        end
        current = parents[1]
        pushfirst!(path, current)
    end
    return path
end

#Finding which information set (by index) a given node belongs to for a given player.
#Returns the 1-based index into game.information_set[player], or 0 if the node
#is not found in any of that player's information sets.
function find_infoset_index(game::ExtensiveFormGame, player::Int, node::Int)
    for (idx, iset) in enumerate(game.information_set[player])
        if node in iset
            return idx
        end
    end
    return 0
end

#Getting the action index for the edge from parent to child.
#Action index = position of child in outneighbors(game.tree, parent).
function get_action_index(game::ExtensiveFormGame, parent::Int, child::Int)
    children = outneighbors(game.tree, parent)
    for (idx, c) in enumerate(children)
        if c == child
            return idx
        end
    end
    error("Node $child is not a child of node $parent.")
end

#Computing the sequence of (info_set_index, action_index) pairs that describe
#the decisions player i makes along the path from root to a given node.
#The node itself is EXCLUDED from the history (we only record PRECEDING decisions).
function player_history(game::ExtensiveFormGame, player::Int, node::Int)
    path = path_from_root(game, node)
    history = Tuple{Int, Int}[]
    
    for k in 1:(length(path) - 1)
        v = path[k]
        if get(game.player_at_node, v, -1) == player
            iset_idx = find_infoset_index(game, player, v)
            action_idx = get_action_index(game, v, path[k + 1])
            push!(history, (iset_idx, action_idx))
        end
    end
    
    return history
end

# ========================================================================================
# Function: enumerate_pure_strategies
# Computes S_i (Equation 6.1): the set of all pure strategies for player i.
# A pure strategy is a complete plan of action — one action chosen at each information set.
#
# Returns a Vector{Vector{Int}} where each inner vector maps info set index → action index.
# For example, [1, 2] means "choose action 1 at info set 1, action 2 at info set 2."
# ========================================================================================

function enumerate_pure_strategies(game::ExtensiveFormGame, player::Int)
    info_sets = game.information_set[player]
    num_info_sets = length(info_sets)
    
    # Determine the number of actions available at each information set
    # (= outdegree of any node in the set; they are all the same by the info set validity condition)
    actions_per_infoset = Int[]
    for iset in info_sets
        first_node = first(iset)
        push!(actions_per_infoset, outdegree(game.tree, first_node))
    end
    
    # Enumerate all combinations via recursive Cartesian product
    pure_strategies = Vector{Vector{Int}}()
    
    function build_strategy!(current::Vector{Int}, depth::Int)
        if depth > num_info_sets
            push!(pure_strategies, copy(current))
            return
        end
        for action in 1:actions_per_infoset[depth]
            push!(current, action)
            build_strategy!(current, depth + 1)
            pop!(current)
        end
    end
    
    build_strategy!(Int[], 1)
    
    println("Player $player has $(length(pure_strategies)) pure strategies across $num_info_sets information set(s).")
    return pure_strategies
end

# ========================================================================================
# Function: has_perfect_recall
# Verifies whether player i satisfies the perfect recall condition (Definition 6.13).
# 
# Condition (a): Every information set of the player intersects every path from the root
#                to a leaf at most once. (The player never "re-enters" the same info set.)
#
# Condition (b): Every two paths from the root that end in the same information set of
#                the player pass through the same preceding information sets, in the same
#                order, and choose the same actions at each. (The player remembers
#                everything about his own past moves.)
# ========================================================================================

function has_perfect_recall(game::ExtensiveFormGame, player::Int)
    info_sets = game.information_set[player]
    
    # ---- Condition (a) ----
    # Check that no root-to-node path passes through the same information set more than once.
    # If a path from root to some node x passes through info set U at two distinct vertices,
    # the player has "forgotten" that he already visited U.
    for (idx, iset) in enumerate(info_sets)
        for node in iset
            path = path_from_root(game, node)
            count_in_iset = count(v -> v in iset, path)
            if count_in_iset > 1
                println("Perfect recall VIOLATED (Condition a): Info set $idx of Player $player")
                println("  The path to node $node passes through this info set at multiple vertices.")
                println("  This means the player revisits the same information set on a single play path.")
                return false
            end
        end
    end
    
    # ---- Condition (b) ----
    # Check that all nodes within the same info set have identical "player histories."
    # That is, the sequence of (info_set_index, action_chosen) at preceding decision nodes
    # of this player must be the same for every node in the info set.
    for (idx, iset) in enumerate(info_sets)
        nodes = collect(iset)
        if length(nodes) <= 1
            continue  # A singleton info set trivially satisfies condition (b)
        end
        
        # Use the first node's history as the reference
        ref_history = player_history(game, player, nodes[1])
        
        for k in 2:length(nodes)
            other_history = player_history(game, player, nodes[k])
            if ref_history != other_history
                println("Perfect recall VIOLATED (Condition b): Info set $idx of Player $player")
                println("  Nodes $(nodes[1]) and $(nodes[k]) have different preceding histories:")
                println("  Node $(nodes[1]): $ref_history")
                println("  Node $(nodes[k]): $other_history")
                println("  The player has forgotten which action he chose at a previous info set.")
                return false
            end
        end
    end
    
    println("Player $player has perfect recall.")
    return true
end


# Function: mixed_to_behavior (Kuhn's Theorem — Forward Direction)
# Theorem 6.15: If player i has perfect recall, every mixed strategy has an equivalent
# behavior strategy.
#
# The conversion uses conditional probabilities. For each information set U and action a:
#
#   b_i(a; U) = Σ_{s ∈ S_i*(U) : s(U) = a} σ_i(s)  /  Σ_{s ∈ S_i*(U)} σ_i(s)
#
# where S_i*(U) is the set of pure strategies that are consistent with the play reaching
# info set U (i.e., they choose the correct action at every preceding info set of player i
# on the path to U).
#
# Input:  mixed_strategy — Vector{Float64} of length |S_i|, indexed in the same order
#         as enumerate_pure_strategies returns.
# Output: BehaviorStrategyProfile for the player.
function mixed_to_behavior(game::ExtensiveFormGame, player::Int, mixed_strategy::Vector{Float64})
    # Validate the mixed strategy is a valid probability distribution
    if !isapprox(sum(mixed_strategy), 1.0; atol=1e-5) || any(p -> p < -1e-10, mixed_strategy)
        error("Invalid mixed strategy: probabilities must be non-negative and sum to 1.")
    end
    
    # Kuhn's Theorem requires perfect recall
    if !has_perfect_recall(game, player)
        error("Player $player does not have perfect recall. Kuhn's Theorem does not guarantee an equivalent behavior strategy exists.")
    end
    
    info_sets = game.information_set[player]
    pure_strategies = enumerate_pure_strategies(game, player)
    
    if length(mixed_strategy) != length(pure_strategies)
        error("Mixed strategy has $(length(mixed_strategy)) entries but player $player has $(length(pure_strategies)) pure strategies.")
    end
    
    distributions = Dict{Int, Vector{Float64}}()
    
    for (u_idx, iset) in enumerate(info_sets)
        num_actions = outdegree(game.tree, first(iset))
        
        # Compute the required preceding history for reaching this info set.
        # By Theorem 6.14 (perfect recall), S_i*(x) = S_i*(x') for all x, x' in the same
        # info set, so we can use any node in the set as the reference.
        ref_node = first(iset)
        required_history = player_history(game, player, ref_node)
        
        # Find S_i*(U): pure strategies whose preceding actions match the required history.
        # A pure strategy s reaches U if, at every preceding info set of the player,
        # s chooses the same action that leads toward U.
        reaching_indices = Int[]
        for (s_idx, strat) in enumerate(pure_strategies)
            matches = true
            for (hist_iset, hist_action) in required_history
                if strat[hist_iset] != hist_action
                    matches = false
                    break
                end
            end
            if matches
                push!(reaching_indices, s_idx)
            end
        end
        
        # Total probability of reaching this info set under the mixed strategy
        total_prob = sum(mixed_strategy[s_idx] for s_idx in reaching_indices)
        
        if total_prob < 1e-12
            # Info set is reached with probability 0 under this mixed strategy.
            # The conditional probability is undefined; we assign uniform by convention.
            println("  Note: Info set $u_idx is reached with probability 0. Assigning uniform distribution by convention.")
            distributions[u_idx] = fill(1.0 / num_actions, num_actions)
        else
            # Compute the conditional probability of each action at this info set
            action_probs = zeros(Float64, num_actions)
            for s_idx in reaching_indices
                action_at_u = pure_strategies[s_idx][u_idx]
                action_probs[action_at_u] += mixed_strategy[s_idx]
            end
            action_probs ./= total_prob
            distributions[u_idx] = action_probs
        end
    end
    
    println("\nMixed -> Behavior conversion complete for Player $player:")
    for u_idx in sort(collect(keys(distributions)))
        println("  Info set $u_idx: $(round.(distributions[u_idx], digits=4))")
    end
    
    return BehaviorStrategyProfile(player, distributions)
end




# Function: behavior_to_mixed (Kuhn's Theorem — Reverse Direction)
# Converts a behavior strategy b_i into an equivalent mixed strategy σ_i.
#
# For each pure strategy s_i, the probability assigned by the equivalent mixed strategy is
# the product of the behavior probabilities at each information set:
#
#   σ_i(s_i) = Π_{U ∈ U_i} b_i(s_i(U); U)
#
# This product runs over ALL information sets of the player (including ones that s_i 
# may never actually reach), which is valid because the probability contributions from
# unreachable info sets correctly distribute mass across the strategy space.
#
# Output: Vector{Float64} of probabilities, one per pure strategy (same ordering as
#         enumerate_pure_strategies).
function behavior_to_mixed(game::ExtensiveFormGame, player::Int, behavior::BehaviorStrategyProfile)
    if behavior.player != player
        error("BehaviorStrategyProfile belongs to player $(behavior.player), not player $player.")
    end
    
    # Kuhn's Theorem requires perfect recall for the reverse direction as well
    if !has_perfect_recall(game, player)
        error("Player $player does not have perfect recall. Kuhn's Theorem does not guarantee an equivalent mixed strategy exists.")
    end
    
    pure_strategies = enumerate_pure_strategies(game, player)
    
    mixed_strategy = Float64[]
    
    for strat in pure_strategies
        # σ(s) = product over all info sets of b(chosen_action; info_set)
        prob = 1.0
        for (u_idx, action) in enumerate(strat)
            prob *= behavior.distributions[u_idx][action]
        end
        push!(mixed_strategy, prob)
    end
    
    println("\nBehavior -> Mixed conversion complete for Player $player:")
    println("  σ = $(round.(mixed_strategy, digits=4))")
    println("  Sum of probabilities: $(round(sum(mixed_strategy), digits=6))")
    
    return mixed_strategy
end



# FUNCTION: compute_outcome_probabilities
# Computes the probability of reaching each terminal node under a given strategy profile.
#
# Uses Equation (6.26): ρ(x; σ) = Π_{i ∈ N ∪ {0}} ρ_i(x; σ_i)
# The product is taken independently over all players and chance, since the lotteries
# conducted by the players are independent.
#
# strategies: Dict mapping player_id → BehaviorStrategyProfile
# Chance probabilities are read directly from game.prob_of_chance.
function compute_outcome_probabilities(game::ExtensiveFormGame, strategies::Dict{Int, BehaviorStrategyProfile})
    terminal_probs = Dict{Int, Float64}()
    
    for v in vertices(game.tree)
        if outdegree(game.tree, v) == 0  # Terminal node
            path = path_from_root(game, v)
            prob = 1.0
            
            for k in 1:(length(path) - 1)
                node = path[k]
                child = path[k + 1]
                action_idx = get_action_index(game, node, child)
                owner = get(game.player_at_node, node, -1)
                
                if owner == 0
                    # Chance node: multiply by the assigned probability
                    prob *= game.prob_of_chance[node][action_idx]
                elseif owner > 0 && haskey(strategies, owner)
                    # Player decision node: multiply by the behavior strategy probability
                    u_idx = find_infoset_index(game, owner, node)
                    prob *= strategies[owner].distributions[u_idx][action_idx]
                end
            end
            
            terminal_probs[v] = prob
        end
    end
    
    println("\nOutcome probabilities:")
    for (node, prob) in sort(collect(terminal_probs))
        println("  Terminal node $node: $(round(prob, digits=6))")
    end
    
    return terminal_probs
end

# Function: are_equivalent
# Checks whether a mixed strategy and a behavior strategy are equivalent in the sense
# of Definition 6.5 and Equation (6.10): they induce the same probability ρ_i(x) of 
# player i reaching every vertex x in the game tree.
#
# For the behavior strategy: ρ_i(x; b_i) = Π_{l=1}^{L_i^x} b_i(a_i(x_i^l → x); U_i(x_i^l))
# For the mixed strategy:    ρ_i(x; σ_i) = Σ_{s_i ∈ S_i*(x)} σ_i(s_i)
function are_equivalent(
    game::ExtensiveFormGame, 
    player::Int, 
    mixed_strategy::Vector{Float64}, 
    behavior::BehaviorStrategyProfile;
    atol::Float64 = 1e-8
)
    if behavior.player != player
        error("BehaviorStrategyProfile belongs to player $(behavior.player), not player $player.")
    end
    
    pure_strategies = enumerate_pure_strategies(game, player)
    
    for v in vertices(game.tree)
        path = path_from_root(game, v)
        
        # ρ_i(x; b_i): product of behavior probabilities at each of player i's
        # decision nodes along the path from root to v (Equation 6.24)
        prob_behavior = 1.0
        for k in 1:(length(path) - 1)
            node = path[k]
            child = path[k + 1]
            if get(game.player_at_node, node, -1) == player
                u_idx = find_infoset_index(game, player, node)
                action_idx = get_action_index(game, node, child)
                prob_behavior *= behavior.distributions[u_idx][action_idx]
            end
        end
        
        # ρ_i(x; σ_i): sum over S_i*(x), i.e., all pure strategies that choose
        # the correct action at every preceding info set of the player (Equation 6.25)
        prob_mixed = 0.0
        for (s_idx, strat) in enumerate(pure_strategies)
            consistent = true
            for k in 1:(length(path) - 1)
                node = path[k]
                child = path[k + 1]
                if get(game.player_at_node, node, -1) == player
                    u_idx = find_infoset_index(game, player, node)
                    action_idx = get_action_index(game, node, child)
                    if strat[u_idx] != action_idx
                        consistent = false
                        break
                    end
                end
            end
            if consistent
                prob_mixed += mixed_strategy[s_idx]
            end
        end
        
        if !isapprox(prob_behavior, prob_mixed; atol=atol)
            println("NOT equivalent at vertex $v:")
            println("  ρ_i(behavior) = $(round(prob_behavior, digits=8))")
            println("  ρ_i(mixed)    = $(round(prob_mixed, digits=8))")
            return false
        end
    end
    
    println("The mixed strategy and behavior strategy are EQUIVALENT for Player $player.")
    return true
end