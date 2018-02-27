module XGrad

export
    xdiff,
    xgrad,
    dgrad,
    @diffrule,
    VectorCodeGen,
    BufCodeGen,
    CuCodeGen,
    # re-export from Espresso
    @get_or_create,    
    __construct,
    # (other) helpers
    ungetindex


include("core.jl")

end # module
