using Agents, Random
using StaticArrays: SVector

# waiting = 0, taken = 1, developed = 0
@enum TreeStatus waiting taken developed

normal = 0
left = π/2
down = π
right = 3π/2

@agent struct Box(GridAgent{2})
    status::TreeStatus = waiting
end

function find_agent_in_position(model, pos)
    for agent in allagents(model)
        if agent.pos == pos
            return agent
        end
    end
    return nothing
end


function box_step(tree::Box, model)
    #Solo si se está "quemando", puede quemar otros agentes
    if tree.status == taken
        #Identifica árboles alrededor del agente
        for neighbor in nearby_agents(tree, model)
            if neighbor.status == waiting
                spread_adjustment = 0
                
                # Dirección del vecino
                dx = neighbor.pos[1] - tree.pos[1]
                dy = neighbor.pos[2] - tree.pos[2]
                if dy < 0  # Norte
                    spread_adjustment += model.south_wind_speed
                elseif dy > 0  # Sur
                    spread_adjustment += -model.south_wind_speed
                end
                if dx < 0  # Este
                    spread_adjustment += model.west_wind_speed
                elseif dx > 0  # Oeste
                    spread_adjustment += -model.west_wind_speed
                end
                # Asegurar que la probabilidad sea de 0% - 100%
                adjusted_spread_prob = model.probability_of_spread + spread_adjustment
                if rand(Uniform(1,100)) <= adjusted_spread_prob
                    neighbor.status = taken
                    if model.bigJumps == true && model.south_wind_speed != 0 && model.west_wind_speed != 0
                        south_min = min(round(Int, model.south_wind_speed / 15), 0)
                        south_max = max(round(Int, model.south_wind_speed / 15), 0)
                        spark_reach_south = round(Int, rand(Uniform(south_min, south_max)))
                        println(spark_reach_south)
                        west_min = min(round(model.west_wind_speed / 15), 0)
                        west_max = max(round(model.west_wind_speed / 15), 0)
                        spark_reach_west = round(Int, rand(Uniform(west_min, west_max)))
                        println(spark_reach_west)
                        if spark_reach_south != 0 && spark_reach_west != 0
                            new_pos = (
                                neighbor.pos[1] - spark_reach_west,
                                neighbor.pos[2] - spark_reach_south
                            )
                            new_neighbor = find_agent_in_position(model, new_pos)
                            if new_neighbor !== nothing
                                println("Cambiando vecino de $(neighbor.pos) a $(new_neighbor.pos)")
                                neighbor = new_neighbor
                                neighbor.status = taken
                                end
                            end
                        end
                    end
                end
            end
            tree.status = developed
        end
    end


    function box_set(; number = 1600.0, initialize = 5, griddims = (80, 80), probability_of_spread = 0, south_wind_speed = 0, west_wind_speed = 0, bigJumps = false)
        space = GridSpaceSingle(griddims; periodic = false, metric = :euclidean)
        box = StandardABM(Box, space; agent_step! = box_step, scheduler = Schedulers.Randomly(), properties = Dict(:probability_of_spread => probability_of_spread, :number => number, :south_wind_speed => south_wind_speed, :west_wind_speed => west_wind_speed, :bigJumps => bigJumps))
        # Convertimos positions(forest) a una lista (Vector)
        all_positions = collect(positions(box))
    
        # Seleccionamos 40 posiciones aleatorias sin reemplazo
        random_positions = sample(all_positions, number, replace=false)
    
        for pos in random_positions
            tree = add_agent!(pos, box)
        end
        return box
    end