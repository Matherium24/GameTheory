using Test
using GameTheory
using Graphs

# ========================================================================================
# Test: Entry Deterrence (Chainstore Game) — Exercise 7.13
#
# Game Tree:
#   Player 1 (Entrant) at node 1: two actions — Enter (→ node 2) or Stay Out (→ node 3)
#   Player 2 (Incumbent) at node 2: two actions — Accommodate (→ node 4) or Fight (→ node 5)
#   Terminal nodes: 3 (Stay Out), 4 (Accommodate), 5 (Fight)
#
# Payoffs (Entrant, Incumbent):
#   Stay Out (node 3): (0, 2)   — Entrant gets nothing, Incumbent keeps monopoly profit
#   Accommodate (node 4): (1, 1) — Both share the market
#   Fight (node 5): (-1, -1)    — Price war, both lose
#
# The Nash equilibrium (Stay Out, Fight) relies on a noncredible threat:
#   the Incumbent threatens to fight, but if entry actually occurs, fighting yields -1
#   while accommodating yields 1. So the Incumbent would never rationally fight.
#
# Backward Induction Result:
#   At node 2, Player 2 chooses Accommodate (payoff 1 > -1).
#   At node 1, Player 1 knows this, so Enter yields 1 > 0 from Stay Out.
#   SPE strategy: (Enter, Accommodate) with payoff (1, 1).
# ========================================================================================

@testset "Backward Induction - Entry Deterrence (Chainstore)" begin
    # 1. Build the game tree: 5 nodes, 2 players
    game = ExtensiveFormGame(5, 2)

    # Edges: root → children
    add_edge!(game.tree, 1, 2)  # Enter
    add_edge!(game.tree, 1, 3)  # Stay Out
    add_edge!(game.tree, 2, 4)  # Accommodate
    add_edge!(game.tree, 2, 5)  # Fight

    # 2. Assign players to decision nodes
    game.player_at_node[1] = 1  # Entrant decides
    game.player_at_node[2] = 2  # Incumbent decides

    # 3. Assign payoffs to terminal nodes
    game.payoff[3] = [0.0, 2.0]   # Stay Out
    game.payoff[4] = [1.0, 1.0]   # Enter → Accommodate
    game.payoff[5] = [-1.0, -1.0] # Enter → Fight

    # 4. Define information sets (perfect information: singletons)
    push!(game.information_set[1], Set([1]))
    push!(game.information_set[2], Set([2]))

    # 5. Validate the game structure
    @test is_valid(game) == true
    @test has_perfect_information(game) == true

    # 6. Run backward induction
    result = backward_induction(game)

    # 7. Verify the SPE strategy
    # At node 2 (Incumbent): action 1 = Accommodate (child node 4)
    @test result.strategy[2] == 1
    # At node 1 (Entrant): action 1 = Enter (child node 2)
    @test result.strategy[1] == 1

    # 8. Verify the SPE payoff at root
    @test result.payoff == [1.0, 1.0]

    # 9. Verify the equilibrium path
    path = backward_induction_path(game, result)
    @test path == [1, 2, 4]  # Root → Enter → Accommodate

    println("\n✓ Entry Deterrence: Backward induction correctly ignores the noncredible \"Fight\" threat.")
end
