include("storage.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

# Dictionary to store simulation instances
instances = Dict()

# Route to start a new simulation
route("/simulations", method = POST) do
    payload = jsonpayload()
    x = payload["dim"][1]
    y = payload["dim"][2]
    number = payload["number"]

    model = initialize_model(griddims = (x, y), number = number)
    id = string(uuid1())  # Create a unique identifier for the model instance
    instances[id] = model  # Store the model in the dictionary

    # Collect all agents (boxes, cars, storages)
    boxes = []
    cars = []
    storages = []
    for agent in allagents(model)
        if agent isa box
            push!(boxes, agent)
        elseif agent isa car
            push!(cars, agent)
        elseif agent isa storage
            push!(storages, agent)
        end
    end
    
    # Return the simulation details with the simulation ID and agents
    json(Dict(:msg => "Simulation started", "Location" => "/simulations/$id", "boxes" => boxes, "cars" => cars, "storages" => storages))
end

# Route to run the simulation for a specific ID
route("/simulations/:id", method = GET) do
    model_id = params(:id)  # Extract the model ID from the URL parameters
    model = instances[model_id]  # Retrieve the corresponding model from the dictionary
    run!(model, 1)  # Run the model for 1 step

    # Collect all agents (boxes, cars, storages) after running the model
    boxes = []
    cars = []
    storages = []
    for agent in allagents(model)
        if agent isa box
            push!(boxes, agent)
        elseif agent isa car
            push!(cars, agent)
        elseif agent isa storage
            push!(storages, agent)
        end
    end
    
    # Return the updated state of the simulation
    json(Dict(:msg => "Simulation step completed", "boxes" => boxes, "cars" => cars, "storages" => storages))
end

# CORS settings
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

# Start the Genie server
up()