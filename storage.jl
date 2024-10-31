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

@agent struct car(GridAgent{2})
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

    for neighbor in allagents(model)
        if isa(neighbor, box) && neighbor.status == waiting
            dist_to_neighbor = abs(neighbor.pos[1] - agent.pos[1]) + abs(neighbor.pos[2] - agent.pos[2])

            if dist_to_neighbor < min_distance
                min_distance = dist_to_neighbor
                closest_box = neighbor
            end
        end
    end

    return closest_box, min_distance
end

function agent_step!(agent::box, model)
    # No action needed for box agents
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
        if isa(neighbor, storage)  
            dist_to_neighbor = abs(neighbor.pos[1] - agent.pos[1]) + abs(neighbor.pos[2] - agent.pos[2])

            if dist_to_neighbor < min_distance
                min_distance = dist_to_neighbor
                closest_storage = neighbor
            end
        end
    end

    return closest_storage, min_distance
end

# Check if another car is already in the target position
function detect_collision(agent::car, target_pos, model)

    for neighbor in allagents(model)
        if isa(neighbor, car) && neighbor !== agent
            if neighbor.pos == target_pos
                return true
            end
        end
    end
    return false
end

# Attempt to move to the new position if no collision is detected
function try_move(agent::car, model, new_position)
    if !detect_collision(agent, new_position, model)
        move_agent!(agent, new_position, model)
        println("Car moved to position $new_position")
        return true 
    else
        println("Car detected another car at $new_position, avoiding collision")
        return false
    end
end

# Try moving randomly in one of the four cardinal directions
function random_move(agent::car, model)
    current_pos = agent.pos
    possible_moves = [
        (current_pos[1] + 1, current_pos[2]),
        (current_pos[1] - 1, current_pos[2]),
        (current_pos[1], current_pos[2] + 1),
        (current_pos[1], current_pos[2] - 1)
    ]
    shuffle!(possible_moves)
    for move in possible_moves
        if !detect_collision(agent, move, model)
            move_agent!(agent, move, model)
            println("Car made a random move to $move")
            return true
        end
    end
    println("Car couldn't make a random move, staying in place")
    return false
end

function agent_step!(agent::car, model)
    if agent.capacity == empty
        closest_box, _ = closest_box_nearby(agent, model)

        if closest_box !== nothing
            target_pos = closest_box.pos
            current_pos = agent.pos

            diff_x = target_pos[1] - current_pos[1]
            diff_y = target_pos[2] - current_pos[2]

            # Try to move in the primary direction (the axis with the larger distance)
            if abs(diff_x) > abs(diff_y)
                new_position = (current_pos[1] + sign(diff_x), current_pos[2])
                if !try_move(agent, model, new_position)  # If blocked, try the secondary direction
                    new_position = (current_pos[1], current_pos[2] + sign(diff_y))
                    if !try_move(agent, model, new_position)
                        random_move(agent, model)  # Try random move if both directions are blocked
                    end
                end
            else
                new_position = (current_pos[1], current_pos[2] + sign(diff_y))
                if !try_move(agent, model, new_position)  # If blocked, try the primary direction
                    new_position = (current_pos[1] + sign(diff_x), current_pos[2])
                    if !try_move(agent, model, new_position)
                        random_move(agent, model)  # Try random move if both directions are blocked
                    end
                end
            end

            if agent.pos == closest_box.pos
                closest_box.status = taken
                agent.capacity = full
                println("Car picked up the box at position $(closest_box.pos), now searching for storage")
            end
        else
            new_position = (agent.pos[1], agent.pos[2] - 1)
            try_move(agent, model, new_position)
        end

    elseif agent.capacity == full
        closest_storage, _ = closest_storage_nearby(agent, model)
        closest_box, _ = closest_box_nearby(agent, model)

        if closest_storage !== nothing && closest_storage.boxes !== 0
            target_pos = closest_storage.pos
            current_pos = agent.pos

            diff_x = target_pos[1] - current_pos[1]
            diff_y = target_pos[2] - current_pos[2]

            if abs(diff_x) > abs(diff_y)
                new_position = (current_pos[1] + sign(diff_x), current_pos[2])
                if !try_move(agent, model, new_position)
                    new_position = (current_pos[1], current_pos[2] + sign(diff_y))
                    if !try_move(agent, model, new_position)
                        random_move(agent, model)
                    end
                end
            else
                new_position = (current_pos[1], current_pos[2] + sign(diff_y))
                if !try_move(agent, model, new_position)
                    new_position = (current_pos[1] + sign(diff_x), current_pos[2])
                    if !try_move(agent, model, new_position)
                        random_move(agent, model)
                    end
                end
            end

            if agent.pos == closest_storage.pos
                agent.capacity = empty
                closest_storage.boxes -= 1
                println("Car delivered the box to storage at position $(closest_storage.pos), now searching for new box")
                closest_box.status = developed
                
            end
        else
            new_position = (agent.pos[1], agent.pos[2] - 1)
            try_move(agent, model, new_position)
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
    bottom_y = griddims[2]
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
    
    num_storages = round(Int, number / num_cars)

    function box_at_position(pos, model)
        for agent in agents_in_position(pos, model)
            if isa(agent, box)
                return true
            end
        end
        return false
    end

    storage_positions = []
    for car_pos in car_positions
        if !box_at_position(car_pos, model)
            add_agent!(storage, model; pos = car_pos) 
            push!(storage_positions, car_pos)
        end
    end

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
