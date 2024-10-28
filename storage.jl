using Agents, Random
using StaticArrays: SVector

# waiting = 0, taken = 1, developed = 0
@enum BoxStatus waiting taken developed
@enum CarStatus empty full

normal = 0
left = π/2
down = π
right = 3π/2

@agent struct box(GridAgent{2})
    status::BoxStatus = waiting
end

@agent struct car(ContinuousAgent{2,Float64})
    street::CarStatus = empty
    orientation::Float64 = normal
end

function find_agent_in_position(pos, model)
    for agent in allagents(model)
        if agent.pos == pos
            return agent
        end
    end
    return nothing
end



function agent_step!(agent::box, model)
    if agent.status == taken
        for neighbor in nearby_agents(agent, model)
            if neighbor.status == waiting
                spread_adjustment = 0
                
                # Calcular las diferencias en posición
                dx = neighbor.pos[1] - agent.pos[1]
                dy = neighbor.pos[2] - agent.pos[2]
                
                # Ajustar según la dirección del viento
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

                # Ajustar la probabilidad de propagación
                adjusted_spread_prob = clamp(model.probability_of_spread + spread_adjustment, 0, 100)
                if rand(Uniform(1, 100)) <= adjusted_spread_prob
                    neighbor.status = taken

                    # Saltos grandes si es necesario
                    if model.bigJumps && model.south_wind_speed != 0 && model.west_wind_speed != 0
                        spark_reach_south = round(Int, rand(Uniform(min(round(Int, model.south_wind_speed / 15), 0), max(round(Int, model.south_wind_speed / 15), 0))))
                        spark_reach_west = round(Int, rand(Uniform(min(round(model.west_wind_speed / 15), 0), max(round(model.west_wind_speed / 15), 0))))
                        
                        if spark_reach_south != 0 && spark_reach_west != 0
                            new_pos = (neighbor.pos[1] - spark_reach_west, neighbor.pos[2] - spark_reach_south)
                            new_neighbor = find_agent_in_position(new_pos, model)
                            if new_neighbor !== nothing
                                neighbor = new_neighbor
                                neighbor.status = taken
                            end
                        end
                    end
                end
            end
        end
        agent.status = developed
    end
end

function agent_step!(agent::car, model)
    if agent.street == empty
        # Lógica para cambiar el estado a 'full'
        agent.street = full
    elseif agent.street == full
        # Lógica para cambiar el estado a 'empty'
        agent.street = empty
    end
end


    function agent_step!(agent::car, model)
        # Logic to handle car behavior, e.g., switching between empty and full
        if car.status == :empty
            # Logic to change status to full
        elseif car.status == :full
            # Logic to change status back to empty
        end
    end

    function initialize_model(; number = 40, griddims = (80, 80))
        space = GridSpaceSingle(griddims; periodic = false, metric = :manhattan)
        model = StandardABM(Union{car, box}, space; agent_step!, scheduler = Schedulers.fastest)
        
        all_positions = [(x, y) for x in 1:griddims[1], y in 1:griddims[2]]
        shuffled_positions = shuffle(all_positions)
        
        for pos in shuffled_positions[1:number]
            add_agent!(box, model; pos = pos)
        end
    
        return model
    end
    