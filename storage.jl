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

@agent struct car(GridAgent{2})  # Cambiado a GridAgent para ser consistente con GridSpace
    street::CarStatus = empty
    orientation::Float64 = normal
end

# Función para encontrar la caja más cercana en un rango de 3x3 usando la distancia Manhattan
function closest_box_nearby(agent::car, model)
    closest_box = nothing
    min_distance = Inf

    # Buscar cajas dentro de un rango de 3x3
    for neighbor in nearby_agents(agent, model, 3.0)
        if isa(neighbor, Box)  # Solo considerar cajas
            # Calcular la distancia Manhattan
            dist_to_neighbor = abs(neighbor.pos[1] - agent.pos[1]) + abs(neighbor.pos[2] - agent.pos[2])

            # Si la distancia está dentro del rango 3x3, seleccionar la caja más cercana
            if dist_to_neighbor <= 3 && dist_to_neighbor < min_distance
                min_distance = dist_to_neighbor
                closest_box = neighbor
            end
        end
    end

    return closest_box, min_distance
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

function initialize_model(; number = 40, griddims = (80, 80))
    space = GridSpaceSingle(griddims; periodic = false, metric = :manhattan)
    model = StandardABM(Union{car, box}, space; agent_step!, scheduler = Schedulers.fastest)
    
    all_positions = [(x, y) for x in 1:griddims[1], y in 1:griddims[2]]
    shuffled_positions = shuffle(all_positions)
    
    num_cars = 5
    bottom_y = griddims[2]  # Última fila (inferior)
    initial_position = div(griddims[1], 10) 
    spacing = 2 * initial_position
    
    car_columns = [initial_position + (i-1) * spacing for i in 1:num_cars]
    car_positions = [(col, bottom_y) for col in car_columns]
    for car_pos in car_positions
        add_agent!(car, model; pos = car_pos)
    end
    restricted_positions = []
    for car_pos in car_positions
        append!(restricted_positions, [(car_pos[1] + dx, car_pos[2] + dy) for dx in -1:1, dy in -1:1])
    end
    
    # Relocalizar las cajas si están demasiado cerca de los autos
    valid_positions = setdiff(shuffled_positions, restricted_positions)
    
    # Asegurarse de que haya suficientes posiciones válidas para todas las cajas
    if length(valid_positions) < number
        error("No hay suficientes posiciones válidas para las cajas")
    end

    # Agregar las cajas a posiciones válidas
    for i in 1:number
        add_agent!(box, model; pos = valid_positions[i])
    end
    
    return model
end
