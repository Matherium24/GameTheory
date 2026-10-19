using Graphs

# Function: has_perfect_information
# A game has perfect information if every information set contains exactly one vertex.
# This is the structural precondition required by the backward induction algorithm.

function has_perfect_information(game::ExtensiveFormGame)
    for (player_id, info_sets) in game.information_set
        for iset in info_sets
            if length(iset) != 1
                println("Game does NOT have perfect information: Player $player_id has an information set with $(length(iset)) vertices.")
                return false
            end
        end
    end
    println("Game has perfect information: Every information set is a singleton.")
    return true
end

# Function: backward_induction
# Computes a subgame perfect equilibrium in pure strategies for a finite extensive-form
# game with perfect information using the backward induction algorithm (Theorem 7.9).

# The backward induction procedure:
#   1. Start with the smallest subgames (roots adjacent to leaves).
#   2. Identify the equilibrium action by finding the choice that maximises the
#      payoff for the active player at that node.
#   3. Replace the subgame with the payoff result of its equilibrium ("fold" it).
#   4. Repeat iteratively, moving backward up the tree to the root.

#
# Algorithm: Post-order traversal via reverse topological sort.
#   - Process the tree from leaves upward to the root.
#   - At each leaf: record its payoff vector directly.
#   - At each decision node: evaluate all children, select the action that maximises
#     the payoff for the player who owns the node, and bubble that payoff vector up.
#   - At each chance node: compute the expected payoff as the weighted sum of children's
#     payoff vectors (using the chance probabilities).
#
# Input:  An ExtensiveFormGame object (must have perfect information).
# Output: A NamedTuple with two fields:
#   - strategy::Dict{Int, Int} — maps each decision node to the index of the chosen action
#                                 (i.e., the position of the optimal child in outneighbors).
#   - payoff::Vector{Float64}  — the expected payoff vector at the root under the SPE.

function backward_induction(game::ExtensiveFormGame)
    # 1. Structural Guardrail: Backward induction requires perfect information
    if !has_perfect_information(game)
        error("Backward induction requires perfect information (every information set must be a singleton).")
    end

    # 2. Compute the reverse topological ordering (leaves first, root last)
    #    Graphs.jl's topological_sort_by_dfs returns root-first; we reverse it.
    topo_order = topological_sort_by_dfs(game.tree)
    reverse_topo = reverse(topo_order)

    # 3. Storage: maps each node to the payoff vector that results from optimal play
    #    in the subgame rooted at that node.
    node_value = Dict{Int, Vector{Float64}}()

    # 4. Storage: maps each decision node to the index of the optimal action chosen
    strategy = Dict{Int, Int}()

    # 5. Process nodes in reverse topological order (post-order)
    for node in reverse_topo
        children = outneighbors(game.tree, node)

        # Case 1: Leaf node — the value IS the payoff vector
        if isempty(children)
            if !haskey(game.payoff, node)
                error("Terminal node $node is missing a payoff vector.")
            end
            node_value[node] = game.payoff[node]

        # Case 2: Chance node (player 0) — compute expected payoff as weighted sum
        elseif get(game.player_at_node, node, -1) == 0
            probs = game.prob_of_chance[node]
            expected = zeros(Float64, game.num_players)
            for (k, child) in enumerate(children)
                expected .+= probs[k] .* node_value[child]
            end
            node_value[node] = expected

        # Case 3: Decision node — the active player picks the action maximising their payoff
        else
            active_player = game.player_at_node[node]

            best_action = 1
            best_payoff_for_player = node_value[children[1]][active_player]

            for k in 2:length(children)
                child_payoff = node_value[children[k]][active_player]
                if child_payoff > best_payoff_for_player
                    best_payoff_for_player = child_payoff
                    best_action = k
                end
            end

            # Record the optimal action and bubble the full payoff vector upward
            strategy[node] = best_action
            node_value[node] = node_value[children[best_action]]
        end
    end

    # 6. Extract the root's value as the equilibrium payoff
    root_payoff = node_value[game.root]

    # 7. Print the result
    println("\n--- Backward Induction Result ---")
    println("Root payoff (SPE): ", root_payoff)
    println("Strategy profile (node → action index):")
    for node in sort(collect(keys(strategy)))
        chosen_child = outneighbors(game.tree, node)[strategy[node]]
        owner = game.player_at_node[node]
        println("  Node $node (Player $owner): action $(strategy[node]) → child node $chosen_child")
    end

    return (strategy = strategy, payoff = root_payoff)
end

# Function: backward_induction_path
# Extracts the equilibrium path from the root to the terminal leaf implied by the
# strategy profile computed via backward induction.
#
# This traces the actual play of the game when all players follow the SPE strategy,
# walking from the root and at each decision node following the action recorded in the
# strategy dictionary.
#
# Input:  game — an ExtensiveFormGame, result — output of backward_induction
# Output: Vector{Int} of nodes visited along the equilibrium path (root to leaf).

function backward_induction_path(game::ExtensiveFormGame, result::NamedTuple)
    path = [game.root]
    current = game.root

    while true
        children = outneighbors(game.tree, current)
        if isempty(children)
            break  # Reached a terminal leaf
        end

        owner = get(game.player_at_node, current, -1)

        if owner == 0
            # Chance node: follow the first action (deterministic path through the tree).
            # In a perfect information game with known chance, we report the most likely path.
            # For the equilibrium payoff, the expected value is already computed in backward_induction.
            push!(path, children[1])
            current = children[1]
        else
            # Decision node: follow the optimal action from the strategy
            action = result.strategy[current]
            next_node = children[action]
            push!(path, next_node)
            current = next_node
        end
    end

    println("\nEquilibrium path (root → leaf): ", path)
    return path
end
