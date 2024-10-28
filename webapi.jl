include("storage.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

instances = Dict()

route("/simulations", method = POST) do
    payload = jsonpayload()
    x = payload["dim"][1]
    y = payload["dim"][2]
    number = payload["number"]

    model = box_set(griddims=(x,y), number =(number))
    id = string(uuid1())
    instances[id] = model

    trees = []
    for tree in allagents(model)
        push!(trees, tree)
    end
    
    json(Dict(:msg => "Hola", "Location" => "/simulations/$id", "trees" => trees))
end

route("/simulations/:id") do
    model = instances[payload(:id)]
    
    run!(model, 1)
    trees = []
    for tree in allagents(model)
        push!(trees, tree)
    end
    
    json(Dict(:msg => "Adios", "trees" => trees))
end

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

up()