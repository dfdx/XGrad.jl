using Documenter, XGrad

makedocs(
    format = :html,
    sitename = "XGrad.jl",
    pages = [
        "Main" => "index.md",
        "Tutorial" => "tutorial.md",
        "Code Discovery" => "codediscovery.md"
    ]
)

deploydocs(
    repo   = "github.com/dfdx/XGrad.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing
)
