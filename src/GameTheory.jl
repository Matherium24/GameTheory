module GameTheory

export ExtensiveFormGame, is_valid
export StrategicFormGame, is_valid, eliminate_strictly_dominated, pure_nash_equilibria

include("ExtensiveFormGame.jl")
include("StrategicFormGame.jl")

end
