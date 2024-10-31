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
    carried_box::Union{box, Nothing} = nothing
    initial_x::Int = 0
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

# Attempt to move to the new position if no collision is detected and the position is not in the restricted area
function try_move!(agent::car, model, dx::Int, dy::Int, griddims)
    current_pos = agent.pos
    new_position = (current_pos[1] + dx, current_pos[2] + dy)
    
    # Check if the new position is in the restricted area (last row)
    if new_position[2] == griddims[2]
        println("Move blocked: Car cannot enter the restricted last row at position $new_position")
        return false
    end

    # Proceed if there’s no collision and within allowed area
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

# Try moving randomly in one of the four cardinal directions while respecting the restricted area
function random_move!(agent::car, model, griddims)
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
        
        # Ensure the car does not attempt to enter the last row
        if target_pos[2] < griddims[2] && !detect_collision(agent, target_pos, model)
            move_agent!(agent, target_pos, model)
            update_orientation!(agent, dx, dy)
            println("Car made a random move to position $(agent.pos) with orientation $(agent.orientation)")
            return true
        end
    end
    println("Car couldn't make a random move without entering the restricted area, staying in place")
    return false
end

function agent_step!(agent::car, model, griddims)
    # Check if the car is empty and needs to find a box
    if agent.capacity === empty
        if any_box_nearby(agent, model, griddims)
            closest_box, _ = closest_box_nearby(agent, model)
            if closest_box !== nothing
                move_towards!(agent, closest_box.pos, model, griddims)
                if agent.pos === closest_box.pos
                    closest_box.status = taken
                    agent.capacity = full
                    agent.carried_box = closest_box
                    println("Car picked up the box at position $(closest_box.pos), now searching for storage")
                end
            end
        else
            # If no boxes found nearby, first move to initial_x
            if agent.pos[1] != agent.initial_x
                move_towards!(agent, (agent.initial_x, agent.pos[2]), model, griddims)
                if agent.pos[1] == agent.initial_x
                    println("Car aligned to initial X position at $(agent.pos)")
                end
            else
                # Then, advance in y
                target_y = agent.pos[2] - 1
                move_towards!(agent, (agent.initial_x, target_y), model, griddims)
                if agent.pos[2] == target_y
                    println("Car advanced in y to $(agent.pos)")
                end
            end
        end
    elseif agent.capacity == full
        if agent.carried_box !== nothing
            move_agent!(agent.carried_box, agent.pos, model)
        end
        
        # Find the closest storage and attempt delivery
        closest_storage, _ = closest_storage_nearby(agent, model)
        if closest_storage !== nothing
            move_towards!(agent, closest_storage.pos, model, griddims)
            
            # Attempt delivery if the car is adjacent to the storage
            if is_adjacent(agent.pos, closest_storage.pos)
                deliver_box_in_front!(agent, model, closest_storage)
                # After delivery, first return to initial_x
                return_to_initial_x!(agent, model, griddims)
            end
        end
    end
end

# Helper function to check if two positions are adjacent (not diagonal)
function is_adjacent(pos1, pos2)
    return (pos1[1] == pos2[1] && abs(pos1[2] - pos2[2]) == 1) || (pos1[2] == pos2[2] && abs(pos1[1] - pos2[1]) == 1)
end

function any_box_nearby(agent::car, model, griddims)
    radius = griddims[2] / 10  # Dynamic radius based on grid's height
    for neighbor in nearby_agents(agent, model, radius)
        if isa(neighbor, box) && neighbor.status == waiting
            return true
        end
    end
    return false
end


function return_to_initial_x!(agent::car, model, griddims)
    current_x = agent.pos[1]
    target_x = agent.initial_x
    if current_x != target_x
        move_towards!(agent, (target_x, agent.pos[2]), model, griddims)
        if agent.pos[1] == target_x
            println("Car returned to initial X position at $(agent.pos)")
        end
    end
end

# Function to deliver the box in front of the storage
function deliver_box_in_front!(Car::car, model, Storage::storage)
    storage_pos = Storage.pos
    car_pos = Car.pos

    # Determine the box delivery position based on the car's relative position to the storage
    box_delivery_pos = if car_pos[1] == storage_pos[1] && car_pos[2] == storage_pos[2] - 1
        (storage_pos[1], storage_pos[2] - 1)  # Car is above storage, deliver box below storage
    elseif car_pos[1] == storage_pos[1] && car_pos[2] == storage_pos[2] - 1
        (storage_pos[1], storage_pos[2] - 1)  # Car is below storage, deliver box above storage
    elseif car_pos[1] == storage_pos[1] - 1 && car_pos[2] == storage_pos[2]
        (storage_pos[1] - 1, storage_pos[2])  # Car is to the right of storage, deliver box to the left
    elseif car_pos[1] == storage_pos[1] - 1 && car_pos[2] == storage_pos[2]
        (storage_pos[1] - 1, storage_pos[2])  # Car is to the left of storage, deliver box to the right
    else
        println("Car is not in a valid adjacent position to deliver the box. Adjust car position.")
        return
    end

    # Check if the front position is available for delivery
    if !detect_collision(Car, box_delivery_pos, model)
        # Move the box to the determined delivery position
        move_agent!(Car.carried_box, box_delivery_pos, model)
        Car.carried_box.status = delivered
        Car.capacity = empty
        Car.carried_box = nothing
        Storage.boxes -= 1
        println("Box delivered in front of storage at $storage_pos with car in position $car_pos")
    else
        println("Delivery position in front of storage is occupied.")
    end
end


# Move towards a target position without entering the restricted last row
function move_towards!(agent::car, target_pos, model, griddims)
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

    # Try primary direction without entering the restricted last row
    if (current_pos[2] + primary[2]) < griddims[2] && try_move!(agent, model, primary[1], primary[2], griddims)
        # Move successful
    elseif (current_pos[2] + secondary[2]) < griddims[2] && try_move!(agent, model, secondary[1], secondary[2], griddims)
        # Move successful
    else
        # Try random move as a last resort
        random_move!(agent, model, griddims)
    end
end

# Agent Step Function for Box (No action needed)
function agent_step!(agent::box, model, griddims)
    # No action needed for box agents
end

# Agent Step Function for Storage (No action needed)
function agent_step!(agent::storage, model, griddims)
    # No action needed for storage agents
end

# Initialize the Model
function initialize_model(; number = 40, griddims = (80, 80))
    space = GridSpace(griddims; periodic = false, metric = :manhattan)
    model = ABM(Union{car, box, storage}, space; agent_step! = (a, m) -> agent_step!(a, m, griddims), scheduler = Schedulers.fastest)

    all_positions = [(x, y) for x in 1:griddims[1], y in 1:griddims[2]]
    shuffled_positions = shuffle(all_positions)

    num_cars = 5
    bottom_y = griddims[2]  # Last row (bottom)
    initial_position = div(griddims[1], 10)
    spacing = 2 * initial_position

    car_columns = [initial_position + (i-1) * spacing for i in 1:num_cars]
    car_positions = [(col, bottom_y) for col in car_columns]
    for car_pos in car_positions
        add_agent!(car, model; pos = car_pos, initial_x = car_pos[1])
    end

    # Collect restricted positions around each car to avoid collisions
    restricted_positions = []
    for car_pos in car_positions
        append!(restricted_positions, [(car_pos[1] + dx, car_pos[2] + dy) for dx in -1:1, dy in -1:1])
    end

    # Define the set of valid positions by excluding restricted positions
    valid_positions = setdiff(shuffled_positions, restricted_positions)

    if length(valid_positions) < number
        error("Not enough valid positions for boxes")
    end

    # Add boxes to valid positions
    for i in 1:number
        add_agent!(box, model; pos = valid_positions[i])
    end

    # Fill the bottom row with storage, excluding car positions
    bottom_row_positions = [(x, bottom_y) for x in 1:griddims[1] if (x, bottom_y) ∉ car_positions]
    
    for pos in bottom_row_positions
        add_agent!(storage, model; pos = pos)
    end

    return model
end
