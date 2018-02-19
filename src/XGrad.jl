module XGrad

export
    xdiff,
    xgrad,
    kgrad,
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
