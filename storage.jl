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
    capacity::CarStatus = empty
    orientation::Float64 = normal
end

@agent struct storage(GridAgent{2})
    boxes::Int = 5
end


# Function to find the closest box using Manhattan distance
function closest_box_nearby(agent::car, model)
    closest_box = nothing
    min_distance = Inf

    # Search for boxes within the entire grid space (expand the search range)
    for neighbor in allagents(model)
        if isa(neighbor, box) && neighbor.status == waiting  # Only consider waiting boxes
            # Calculate the Manhattan distance
            dist_to_neighbor = abs(neighbor.pos[1] - agent.pos[1]) + abs(neighbor.pos[2] - agent.pos[2])

            # Select the closest box
            if dist_to_neighbor < min_distance
                min_distance = dist_to_neighbor
                closest_box = neighbor
            end
        end
    end

    return closest_box, min_distance
end

function agent_step!(agent::box, model)
    # No action needed for storage agents
end

function agent_step!(agent::storage, model)
    # No action needed for storage agents
end

# Function to find the closest storage using Manhattan distance
function closest_storage_nearby(agent::car, model)
    closest_storage = nothing
    min_distance = Inf

    # Search for storage agents within the entire grid space (expand the search range)
    for neighbor in allagents(model)
        if isa(neighbor, storage)  # Only consider storage agents
            # Calculate the Manhattan distance
            dist_to_neighbor = abs(neighbor.pos[1] - agent.pos[1]) + abs(neighbor.pos[2] - agent.pos[2])

            # Select the closest storage
            if dist_to_neighbor < min_distance
                min_distance = dist_to_neighbor
                closest_storage = neighbor
            end
        end
    end

    return closest_storage, min_distance
end


function agent_step!(agent::car, model)
    if agent.capacity == empty
        closest_box, _ = closest_box_nearby(agent, model)

        if closest_box !== nothing
            target_pos = closest_box.pos
            current_pos = agent.pos

            diff_x = target_pos[1] - current_pos[1]
            diff_y = target_pos[2] - current_pos[2]

            if abs(diff_x) > abs(diff_y)
                new_position = (current_pos[1] + sign(diff_x), current_pos[2])
            else
                new_position = (current_pos[1], current_pos[2] + sign(diff_y))
            end

            move_agent!(agent, new_position, model)

            if agent.pos == closest_box.pos
                closest_box.status = taken
                agent.capacity = full 
                #println("Car picked up the box at position $(closest_box.pos), now searching for storage")
            end
        else
            new_position = (agent.pos[1], agent.pos[2] - 1)
            move_agent!(agent, new_position, model)
            #println("No box found, moving randomly to position $new_position")
        end

    elseif agent.capacity == full
        closest_storage, _ = closest_storage_nearby(agent, model)

        if closest_storage !== nothing
            target_pos = closest_storage.pos
            current_pos = agent.pos

            diff_x = target_pos[1] - current_pos[1]
            diff_y = target_pos[2] - current_pos[2]

            if abs(diff_x) > abs(diff_y)
                new_position = (current_pos[1] + sign(diff_x), current_pos[2])
            else
                new_position = (current_pos[1], current_pos[2] + sign(diff_y))
            end

            move_agent!(agent, new_position, model)
            #println("Car moving to storage at position $(closest_storage.pos)")

            if agent.pos == closest_storage.pos
                agent.capacity = empty
                closest_storage.boxes += 1
                #println("Car delivered the box to storage at position $(closest_storage.pos), now searching for new box")
            end
        else
            new_position = (agent.pos[1], agent.pos[2] - 1)
            move_agent!(agent, new_position, model)
            #println("No storage found, moving randomly to position $new_position")
        end
    end
end

function initialize_model(; number = 40, griddims = (80, 80))
    space = GridSpace(griddims; periodic = false, metric = :manhattan)
    model = StandardABM(Union{car, box, storage}, space; agent_step!, scheduler = Schedulers.fastest)
    matrix = fill(1, griddims...)
    
    all_positions = [(x, y) for x in 1:griddims[1], y in 1:griddims[2]]
    shuffled_positions = shuffle(all_positions)
    
    num_cars = 5
    bottom_y = griddims[2]  # Last row (bottom)
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
    
    valid_positions = setdiff(shuffled_positions, restricted_positions)
    
    if length(valid_positions) < number
        error("No hay suficientes posiciones válidas para las cajas")
    end

    # Add boxes to valid positions
    for i in 1:number
        add_agent!(box, model; pos = valid_positions[i])
    end
    
    # Calculate number of storage areas needed
    num_storages = round(Int, number / num_cars)

    # Function to check if a box exists at a given position
    function box_at_position(pos, model)
        for agent in agents_in_position(pos, model)
            if isa(agent, box)
                return true
            end
        end
        return false
    end

    # Place one storage area on each car's position, only if there's no box already there
    storage_positions = []
    for car_pos in car_positions
        if !box_at_position(car_pos, model)
            add_agent!(storage, model; pos = car_pos)  # Example capacity
            push!(storage_positions, car_pos)
        end
    end

    # Add remaining storage areas at random border positions if no box is already present
    remaining_storages = num_storages - length(storage_positions)
    if remaining_storages > 0
        border_positions = [(x, 1) for x in 1:griddims[1]]  # Top border
        append!(border_positions, [(x, griddims[2]) for x in 1:griddims[1]])  # Bottom border
        append!(border_positions, [(1, y) for y in 1:griddims[2]])  # Left border
        append!(border_positions, [(griddims[1], y) for y in 1:griddims[2]])  # Right border
        shuffled_borders = shuffle(border_positions)

        for i in 1:remaining_storages
            if !box_at_position(shuffled_borders[i], model)
                add_agent!(storage, model; pos = shuffled_borders[i])
            end
        end
    end
    
    return model
end
