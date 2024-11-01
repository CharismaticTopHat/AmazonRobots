include("storage.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

# Diccionario para almacenar instancias de simulación
instances = Dict()

# Ruta para iniciar una nueva simulación
route("/simulations", method = POST) do
    payload = jsonpayload()
    x = payload["dim"][1]
    y = payload["dim"][2]
    number = payload["number"]

    model = initialize_model(griddims = (x, y), number = number)
    id = string(uuid1())  # Crea un identificador único para la instancia de modelo
    instances[id] = model  # Almacena el modelo en el diccionario

    # Recopila todos los agentes (cajas, coches, almacenamientos)
    boxes = []
    robots = []
    storages = []
    for agent in allagents(model)
        if agent isa box
            push!(boxes, agent)
        elseif agent isa robot
            push!(robots, agent)
        elseif agent isa storage
            push!(storages, agent)
        end
    end
    
    # Retorna los detalles de la simulación con el ID y agentes de la simulación
    json(Dict(:msg => "Simulación iniciada", "Location" => "/simulations/$id", "boxes" => boxes, "robots" => robots, "storages" => storages))
end

# Ruta para ejecutar la simulación con un ID específico
route("/simulations/:id", method = GET) do
    model_id = params(:id)  # Extrae el ID del modelo desde los parámetros de la URL
    model = instances[model_id]  # Recupera el modelo correspondiente del diccionario
    run!(model, 1)  # Ejecuta el modelo por un paso

    # Recopila todos los agentes (cajas, coches, almacenamientos) tras ejecutar el modelo
    boxes = []
    robots = []
    storages = []
    for agent in allagents(model)
        if agent isa box
            push!(boxes, agent)
        elseif agent isa robot
            push!(robots, agent)
        elseif agent isa storage
            push!(storages, agent)
        end
    end
    
    # Retorna el estado actualizado de la simulación
    json(Dict(:msg => "Paso de simulación completado", "boxes" => boxes, "robots" => robots, "storages" => storages))
end

# Configuración de CORS (Cross-Origin Resource Sharing)
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

# Inicia el servidor de Genie
up()