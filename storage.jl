using Agents, Random
using StaticArrays: SVector

# Definición de Enums
@enum BoxStatus waiting taken delivered
@enum RobotStatus empty full
@enum Movement moving stop

# Constantes de Orientación en Radianes
orient_up = 0
orient_left = 1
orient_down = 2
orient_right = 3

# Definición de Estructuras de Agentes
@agent struct box(GridAgent{2})
    status::BoxStatus = waiting
end

@agent struct robot(GridAgent{2})
    capacity::RobotStatus = empty
    orientation::Float64 = orient_right
    carried_box::Union{box,Nothing} = nothing
    initial_x::Int = 0
    stopped::Movement = moving
    counter::Int = 0
    nextPos::Tuple{Float64,Float64} = (0.0, 0.0)
end

@agent struct storage(GridAgent{2})
    boxes::Int = 5
end

# Función para encontrar la caja más cercana usando distancia Manhattan
function closest_box_nearby(agent::robot, model)
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

# Función para encontrar el almacenamiento más cercano usando distancia Manhattan
function closest_storage_nearby(agent::robot, model)
    closest_storage = nothing
    min_distance = Inf

    for neighbor in allagents(model)
        if isa(neighbor, storage)
            if neighbor.boxes != 0
                dist_to_neighbor = abs(neighbor.pos[1] - agent.pos[1]) + abs(neighbor.pos[2] - agent.pos[2])
                if dist_to_neighbor < min_distance
                    min_distance = dist_to_neighbor
                    closest_storage = neighbor
                end
            end
        end
    end
    return closest_storage, min_distance
end

# Verifica si otro coche ya está en la posición de destino
function detect_collision(agent::robot, target_pos, model)
    for neighbor in allagents(model)
        if isa(neighbor, robot) && neighbor !== agent
            if neighbor.pos == target_pos
                return true
            end
        end
    end
    return false
end

function update_orientation_and_counter!(agent::robot, dx::Int, dy::Int)
    new_orientation = if dx == 1
        orient_right
    elseif dx == -1
        orient_left
    elseif dy == 1
        orient_up
    elseif dy == -1
        orient_down
    else
        agent.orientation  # No change if no movement
    end

    if agent.orientation != new_orientation
        angle_diff = abs(agent.orientation - new_orientation)
        agent.counter = angle_diff == π ? 18 : 9  # Adjust counter based on rotation needed
        agent.orientation = new_orientation
    else
        agent.counter = 0  # No counter if no change in orientation
    end
end

# Actualiza la orientación del coche según la dirección de movimiento
function update_orientation!(agent::robot, dx::Int, dy::Int)
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

# Intenta moverse a la nueva posición si no hay colisión y no es una zona restringida
function try_move!(agent::robot, model, dx::Int, dy::Int, griddims)
    current_pos = agent.pos
    new_position = (current_pos[1] + dx, current_pos[2] + dy)

    if new_position[2] == griddims[2]
        return false
    end

    if !detect_collision(agent, new_position, model)
        move_agent!(agent, new_position, model)
        update_orientation_and_counter!(agent, dx, dy)  # Update orientation for any movement
        return true
    else
        return false
    end
end


function agent_step!(agent::robot, model, griddims)
    # Decrementa el contador de espera del agente en caso de rotación
    if agent.counter > 0
        agent.counter -= 1
        return  # No hace el resto del código.
    end
    # Verifica si el coche está vacío y necesita encontrar una caja
    if agent.capacity === empty
        if any_box_nearby(agent, model, griddims)
            closest_box, _ = closest_box_nearby(agent, model)
            if closest_box !== nothing
                move_towards!(agent, closest_box.pos, model, griddims)
                if agent.pos === closest_box.pos
                    closest_box.status = taken
                    agent.capacity = full
                    agent.carried_box = closest_box
                end
            end
        else
            # Si no se encuentran cajas cercanas y el coche ha alcanzado el límite superior de la cuadrícula, se detiene
            if agent.pos[2] == 1
                agent.stopped = stop
                return
            end

            # Si no está en el límite superior, primero se mueve hacia initial_x
            if agent.pos[1] != agent.initial_x
                move_towards!(agent, (agent.initial_x, agent.pos[2]), model, griddims)
            else
                # Luego, avanza en y
                target_y = agent.pos[2] - 1
                move_towards!(agent, (agent.initial_x, target_y), model, griddims)
            end
        end
    elseif agent.capacity == full
        if agent.carried_box !== nothing
            move_agent!(agent.carried_box, agent.pos, model)
        end

        # Encuentra el almacenamiento más cercano e intenta hacer la entrega
        closest_storage, _ = closest_storage_nearby(agent, model)
        if closest_storage !== nothing
            move_towards!(agent, closest_storage.pos, model, griddims)

            # Intenta la entrega si el coche está adyacente al almacenamiento
            if is_adjacent(agent.pos, closest_storage.pos)
                deliver_box_in_front!(agent, model, closest_storage)
                return_to_initial_x!(agent, model, griddims)
            end
        end
    end
end

# Función auxiliar para verificar si dos posiciones son adyacentes (sin diagonal)
function is_adjacent(pos1, pos2)
    return (pos1[1] == pos2[1] && abs(pos1[2] - pos2[2]) == 1) || (pos1[2] == pos2[2] && abs(pos1[1] - pos2[1]) == 1)
end

function any_box_nearby(agent::robot, model, griddims)
    radius = griddims[2] / 10
    for neighbor in nearby_agents(agent, model, radius)
        if isa(neighbor, box) && neighbor.status == waiting
            return true
        end
    end
    return false
end

function return_to_initial_x!(agent::robot, model, griddims)
    current_x = agent.pos[1]
    target_x = agent.initial_x
    if current_x != target_x
        move_towards!(agent, (target_x, agent.pos[2]), model, griddims)
    end
end

# Función para entregar la caja frente al almacenamiento
function deliver_box_in_front!(Robot::robot, model, Storage::storage)
    storage_pos = Storage.pos
    robot_pos = Robot.pos

    # Determina la posición de entrega de la caja según la posición relativa del coche
    box_delivery_pos = if robot_pos[1] == storage_pos[1] && robot_pos[2] == storage_pos[2] - 1
        (storage_pos[1], storage_pos[2] - 1)
    elseif robot_pos[1] == storage_pos[1] && robot_pos[2] == storage_pos[2] - 1
        (storage_pos[1], storage_pos[2] - 1)
    elseif robot_pos[1] == storage_pos[1] - 1 && robot_pos[2] == storage_pos[2]
        (storage_pos[1] - 1, storage_pos[2])
    elseif robot_pos[1] == storage_pos[1] - 1 && robot_pos[2] == storage_pos[2]
        (storage_pos[1] - 1, storage_pos[2])
    else
        return
    end

    # Verifica si la posición de entrega está disponible
    if !detect_collision(Robot, box_delivery_pos, model)
        move_agent!(Robot.carried_box, box_delivery_pos, model)
        Robot.carried_box.status = delivered
        Robot.capacity = empty
        Robot.carried_box = nothing
        Storage.boxes -= 1
    end
end

# Mover hacia una posición objetivo sin entrar en la última fila
function move_towards!(agent::robot, target_pos, model, griddims)
    current_pos = agent.pos
    diff_x = target_pos[1] - current_pos[1]
    diff_y = target_pos[2] - current_pos[2]

    # Determina direcciones primaria y secundaria
    primary, secondary = if abs(diff_x) > abs(diff_y)
        ((sign(diff_x), 0), (0, sign(diff_y)))
    else
        ((0, sign(diff_y)), (sign(diff_x), 0))
    end

    # Intenta la dirección primaria sin entrar en la última fila
    if (current_pos[2] + primary[2]) < griddims[2] && try_move!(agent, model, primary[1], primary[2], griddims)
        # Movimiento exitoso
        update_orientation_and_counter!(agent, primary[1], primary[2])
    elseif (current_pos[2] + secondary[2]) < griddims[2] && try_move!(agent, model, secondary[1], secondary[2], griddims)
        # Movimiento exitoso
        update_orientation_and_counter!(agent, secondary[1], secondary[2])
    else
        println("No se encuentra manera de llegar al destino deseado. Se detendrá el agente.")
    end
end

# Funciones de paso de agente para Caja y Almacenamiento (sin acción)
function agent_step!(agent::box, model, griddims)
end

function agent_step!(agent::storage, model, griddims)
end

# Inicializa el modelo
function initialize_model(; number=40, griddims=(80, 80))
    space = GridSpace(griddims; periodic=false, metric=:manhattan)
    model = ABM(Union{robot,box,storage}, space; (agent_step!)=(a, m) -> agent_step!(a, m, griddims), scheduler=Schedulers.fastest)

    all_positions = [(x, y) for x in 1:griddims[1], y in 1:griddims[2]-1]
    shuffled_positions = shuffle(all_positions)

    num_robots = 5
    bottom_y = griddims[2]
    initial_position = div(griddims[1], 10)
    spacing = 2 * initial_position

    robot_columns = [initial_position + (i - 1) * spacing for i in 1:num_robots]
    robot_positions = [(col, bottom_y) for col in robot_columns]
    for robot_pos in robot_positions
        add_agent!(robot, model; pos=robot_pos, initial_x=robot_pos[1])
    end

    restricted_positions = []
    for robot_pos in robot_positions
        append!(restricted_positions, [(robot_pos[1] + dx, robot_pos[2] + dy) for dx in -1:1, dy in -1:1])
    end

    valid_positions = setdiff(shuffled_positions, restricted_positions)

    if length(valid_positions) < number
        error("No hay suficientes posiciones válidas para las cajas")
    end

    # Añade cajas a posiciones válidas
    for i in 1:number
        add_agent!(box, model; pos=valid_positions[i])
    end

    # Llena la última fila con almacenamiento, excluyendo posiciones de coches
    bottom_row_positions = [(x, bottom_y) for x in 1:griddims[1] if (x, bottom_y) ∉ robot_positions]

    for pos in bottom_row_positions
        add_agent!(storage, model; pos=pos)
    end

    return model
end
