module XGrad

export
    xdiff,
    xgrad,
    @diffrule,
    VectorCodeGen,
    BufCodeGen,
    CuCodeGen,
    # jacobian
    jacobian,
    # re-export from Espresso
    @get_or_create,    
    __construct,
    # (other) helpers
    ungetindex,
    ungetindex!,
    outer_cat


include("core.jl")

end # module
