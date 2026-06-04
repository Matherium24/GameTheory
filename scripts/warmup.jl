println("Welcome to Game Theory Warm-up")
println("Example of Prisoner's Dilemma")

payoffs = [
    (-2,-2) (0,-3);
    (-3,0) (-1,-1)
]

function get_payoffs(p1::Int, p2::Int)
    return payoffs[p1,p2]
end

function get_payoffs(p1::String, p2::String)
    row = p1 == "Defect" ? 1 : 2
    col = p2 == "Defect" ? 1 : 2
    return get_payoffs(row, col)    
end

actions = ["Defect", "Cooperate"]

println("The payoff to the player when choosing the action: ")

for a1 in actions
    for a2 in actions
        println("( $a1, $a2) is $(get_payoffs(a1, a2))")
    end
end