module XGrad

export
    xdiff,
    @diffrule,
    VectorCodeGen,
    BufCodeGen,
    CuCodeGen,
    # re-export from Espresso
    @get_or_create

include("core.jl")

end # module
