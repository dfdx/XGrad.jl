module XGrad

export
    xdiff,
    @diffrule,
    # re-export from Espresso
    @get_or_create

include("core.jl")

end # module
