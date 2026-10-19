using Test
using GameTheory
using Graphs

# ========================================================================================
# Test: Ultimatum Game — Exercise 7.5
#
# Game Tree (discrete version with 3 possible offers):
#   Player 1 (Proposer) at node 1: three actions — Offer 0 (→2), Offer 1 (→3), Offer 2 (→4)
#   Player 2 (Responder) at each of nodes 2, 3, 4: two actions — Accept or Reject
#
#   The total pie is 2 units. Player 1 offers x ∈ {0, 1, 2} to Player 2.
#     - If Player 2 Accepts: payoffs are (2-x, x).
#     - If Player 2 Rejects: payoffs are (0, 0).
#
# Nodes:
#   1:  Player 1 (Proposer) — root
#   2:  Player 2 (Responder) — after Offer 0
#   3:  Player 2 (Responder) — after Offer 1
#   4:  Player 2 (Responder) — after Offer 2
#   5:  Terminal — Offer 0, Accept  → (2, 0)
#   6:  Terminal — Offer 0, Reject  → (0, 0)
#   7:  Terminal — Offer 1, Accept  → (1, 1)
#   8:  Terminal — Offer 1, Reject  → (0, 0)
#   9:  Terminal — Offer 2, Accept  → (0, 2)
#   10: Terminal — Offer 2, Reject  → (0, 0)
#
# Backward Induction Result:
#   At node 2: P2 compares Accept (payoff 0) vs Reject (payoff 0). Tie → picks action 1 (Accept).
#   At node 3: P2 compares Accept (payoff 1) vs Reject (payoff 0). Accept wins.
#   At node 4: P2 compares Accept (payoff 2) vs Reject (payoff 0). Accept wins.
#   At node 1: P1 compares Offer 0 → (2,0), Offer 1 → (1,1), Offer 2 → (0,2).
#              P1 maximises their own payoff: Offer 0 gives 2, which is the best.
#   SPE: (Offer 0, Accept all) with payoff (2, 0).
# ========================================================================================

@testset "Backward Induction - Ultimatum Game" begin
    # 1. Build the game tree: 10 nodes, 2 players
    game = ExtensiveFormGame(10, 2)

    # Root: Player 1's three offers
    add_edge!(game.tree, 1, 2)   # Offer 0
    add_edge!(game.tree, 1, 3)   # Offer 1
    add_edge!(game.tree, 1, 4)   # Offer 2

    # Player 2's Accept/Reject at each offer node
    add_edge!(game.tree, 2, 5)   # Offer 0 → Accept
    add_edge!(game.tree, 2, 6)   # Offer 0 → Reject
    add_edge!(game.tree, 3, 7)   # Offer 1 → Accept
    add_edge!(game.tree, 3, 8)   # Offer 1 → Reject
    add_edge!(game.tree, 4, 9)   # Offer 2 → Accept
    add_edge!(game.tree, 4, 10)  # Offer 2 → Reject

    # 2. Assign players to decision nodes
    game.player_at_node[1] = 1   # Proposer
    game.player_at_node[2] = 2   # Responder (after Offer 0)
    game.player_at_node[3] = 2   # Responder (after Offer 1)
    game.player_at_node[4] = 2   # Responder (after Offer 2)

    # 3. Assign payoffs to terminal nodes
    game.payoff[5]  = [2.0, 0.0]  # Offer 0 → Accept
    game.payoff[6]  = [0.0, 0.0]  # Offer 0 → Reject
    game.payoff[7]  = [1.0, 1.0]  # Offer 1 → Accept
    game.payoff[8]  = [0.0, 0.0]  # Offer 1 → Reject
    game.payoff[9]  = [0.0, 2.0]  # Offer 2 → Accept
    game.payoff[10] = [0.0, 0.0]  # Offer 2 → Reject

    # 4. Define information sets (perfect information: singletons)
    push!(game.information_set[1], Set([1]))
    push!(game.information_set[2], Set([2]))
    push!(game.information_set[2], Set([3]))
    push!(game.information_set[2], Set([4]))

    # 5. Validate the game structure
    @test is_valid(game) == true
    @test has_perfect_information(game) == true

    # 6. Run backward induction
    result = backward_induction(game)

    # 7. Verify the SPE strategy
    # At node 2 (Responder, Offer 0): Accept (action 1) — ties broken by first action
    @test result.strategy[2] == 1
    # At node 3 (Responder, Offer 1): Accept (action 1) — payoff 1 > 0
    @test result.strategy[3] == 1
    # At node 4 (Responder, Offer 2): Accept (action 1) — payoff 2 > 0
    @test result.strategy[4] == 1
    # At node 1 (Proposer): Offer 0 (action 1) — payoff 2 > 1 > 0
    @test result.strategy[1] == 1

    # 8. Verify the SPE payoff at root
    @test result.payoff == [2.0, 0.0]

    # 9. Verify the equilibrium path
    path = backward_induction_path(game, result)
    @test path == [1, 2, 5]  # Root → Offer 0 → Accept

    println("\n✓ Ultimatum Game: Proposer offers the minimum (0), Responder accepts.")
end
