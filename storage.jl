using Agents, Random
using StaticArrays: SVector

# Define Enums
@enum BoxStatus waiting taken delivered
@enum CarStatus empty full

# Define Orientation Constants in Radians with Unique Names
orient_up = 0
orient_left = 1
orient_down = 2
orient_right = 3

# Define Agent Structures
@agent struct box(GridAgent{2})
    status::BoxStatus = waiting
end

@agent struct car(GridAgent{2})
    capacity::CarStatus = empty
    orientation::Float64 = orient_up
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

# Function to find the closest storage using Manhattan distance
function closest_storage_nearby(agent::car, model)
    closest_storage = nothing
    min_distance = Inf

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

# Function to update orientation based on movement direction
function update_orientation!(agent::car, dx::Int, dy::Int)
    if dx == 1
        agent.orientation = orient_right
    elseif dx == -1
        agent.orientation = orient_left
    elseif dy == 1
        agent.orientation = orient_up
    elseif dy == -1
        agent.orientation = orient_down
    end
end

# Attempt to move to the new position if no collision is detected
function try_move!(agent::car, model, dx::Int, dy::Int)
    current_pos = agent.pos
    new_position = (current_pos[1] + dx, current_pos[2] + dy)
    
    if !detect_collision(agent, new_position, model)
        move_agent!(agent, new_position, model)
        update_orientation!(agent, dx, dy)
        println("Car moved to position $new_position with orientation $(agent.orientation)")
        return true 
    else
        println("Car detected another car at $new_position, avoiding collision")
        return false
    end
end

# Try moving randomly in one of the four cardinal directions
function random_move!(agent::car, model)
    current_pos = agent.pos
    possible_moves = [
        (1, 0),   # Right
        (-1, 0),  # Left
        (0, 1),   # Up
        (0, -1)   # Down
    ]
    shuffle!(possible_moves)
    for (dx, dy) in possible_moves
        target_pos = (current_pos[1] + dx, current_pos[2] + dy)
        if !detect_collision(agent, target_pos, model)
            move_agent!(agent, target_pos, model)
            update_orientation!(agent, dx, dy)
            println("Car made a random move to position $(agent.pos) with orientation $(agent.orientation)")
            return true
        end
    end
    println("Car couldn't make a random move, staying in place")
    return false
end

# Agent Step Function for Car
function agent_step!(agent::car, model)
    if agent.capacity == empty
        closest_box, _ = closest_box_nearby(agent, model)

        if closest_box !== nothing
            target_pos = closest_box.pos
            current_pos = agent.pos

            diff_x = target_pos[1] - current_pos[1]
            diff_y = target_pos[2] - current_pos[2]

            # Determine primary and secondary directions
            if abs(diff_x) > abs(diff_y)
                primary = (sign(diff_x), 0)
                secondary = (0, sign(diff_y))
            else
                primary = (0, sign(diff_y))
                secondary = (sign(diff_x), 0)
            end

            # Try primary direction
            if try_move!(agent, model, primary[1], primary[2])
                # Move successful
            else
                # Try secondary direction
                if try_move!(agent, model, secondary[1], secondary[2])
                    # Move successful
                else
                    # Try random move
                    random_move!(agent, model)
                end
            end

            # Check if arrived at the box
            if agent.pos == closest_box.pos
                closest_box.status = taken
                agent.capacity = full
                println("Car picked up the box at position $(closest_box.pos), now searching for storage")
            end
        else
            # No box found, try moving down
            try_move!(agent, model, 0, -1)
        end

    elseif agent.capacity == full
        closest_storage, _ = closest_storage_nearby(agent, model)

        if closest_storage !== nothing && closest_storage.boxes > 0
            target_pos = closest_storage.pos
            current_pos = agent.pos

            diff_x = target_pos[1] - current_pos[1]
            diff_y = target_pos[2] - current_pos[2]

            # Determine primary and secondary directions
            if abs(diff_x) > abs(diff_y)
                primary = (sign(diff_x), 0)
                secondary = (0, sign(diff_y))
            else
                primary = (0, sign(diff_y))
                secondary = (sign(diff_x), 0)
            end

            # Try primary direction
            if try_move!(agent, model, primary[1], primary[2])
                # Move successful
            else
                # Try secondary direction
                if try_move!(agent, model, secondary[1], secondary[2])
                    # Move successful
                else
                    # Try random move
                    random_move!(agent, model)
                end
            end

            # Check if arrived at the storage
            if agent.pos == closest_storage.pos
                agent.capacity = empty
                closest_storage.boxes -= 1
                println("Car delivered the box to storage at position $(closest_storage.pos), now searching for new box")
                # Update the box status to delivered
                for neighbor in allagents(model)
                    if isa(neighbor, box) && neighbor.status == taken
                        neighbor.status = delivered
                        break
                    end
                end
            end
        else
            # No storage found or storage full, try moving down
            try_move!(agent, model, 0, -1)
        end
    end
end

# Agent Step Function for Box (No action needed)
function agent_step!(agent::box, model)
    # No action needed for box agents
end

# Agent Step Function for Storage (No action needed)
function agent_step!(agent::storage, model)
    # No action needed for storage agents
end

# Initialize the Model
function initialize_model(; number = 40, griddims = (80, 80))
    space = GridSpace(griddims; periodic = false, metric = :manhattan)
    model = ABM(Union{car, box, storage}, space; agent_step!, scheduler = Schedulers.fastest)

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

    # Fill the entire bottom row with storage areas (loading zones)
    bottom_row_positions = [(x, bottom_y) for x in 1:griddims[1]]  # Entire bottom row

    for pos in bottom_row_positions
        add_agent!(storage, model; pos = pos)
    end

    return model
end
