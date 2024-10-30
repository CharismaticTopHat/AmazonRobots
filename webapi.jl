include("storage.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

instances = Dict()

route("/simulations", method = POST) do
    payload = jsonpayload()
    #x = payload["dim"][1]
    #y = payload["dim"][2]
    #number = payload["number"]

    model = initialize_model(griddims=(80,80), number =(80))
    id = string(uuid1())
    instances[id] = model

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
    
    json(Dict("Location" => "/simulations/$id", "boxes" => boxes, "cars" => cars, "storages" => storages))
end

route("/simulations/:id") do

    model_id = payload(:id)
    model = instances[model_id]
    run!(model, 1)

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
    
    json(Dict("boxes" => boxes, "cars" => cars, "storages" => storages))
end

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

up()