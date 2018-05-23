# jacobian.jl - experimental support for finding Jacobians

function jacobian(ex; ctx=Dict(), inputs...)
    ctx = to_context(ctx)
    codegen = @get_or_create(ctx, :codegen, autoselect_codegen(inputs))
    ctx[:bitness] = sizeof(codegen.eltyp) * 8
    # inputs = unconvert_cuarrays(inputs)
    g = ExGraph(ex; ctx=ctx, inputs...)
    evaluate!(g)
    z = @get_or_create(g.ctx, :loss, varname(g.tape[end]))
    z_len = g[z] |> getvalue |> length
    dzdz_var = deriv_name(z, z)
    deriv_vars = [deriv_name(g.ctx[:loss], var) for (var, _) in inputs]
    deriv_parts = Dict(v => Symbol[] for v in deriv_vars)
    dgs = Array{ExGraph}(z_len)
    for i in 1:z_len
        # set seed to array with 1 in ith position and 0s for all others
        g.ctx[:seed] = zeros(eltype(getvalue(g[end])), z_len)
        g.ctx[:seed][i] = 1
        # find gradient graph of ith output
        g, dg = _xdiff(g)
        # rename derivative vars adding their index
        to_rename = [deriv_vars; dzdz_var]
        to_rename_dict = Dict(v => Symbol(string(v) * "!$i") for v in to_rename)
        Espresso.rename!(dg, to_rename_dict)
        dgs[i] = dg
        for deriv_var in deriv_vars
            push!(deriv_parts[deriv_var], Symbol(string(deriv_var) * "!$i"))
        end
    end
    # concat all subgraphs
    rg = reduce(cat, g, dgs)
    # add nodes for concatenated derivatives
    for deriv_var in deriv_vars
        parts = deriv_parts[deriv_var]
        parse!(rg, :($deriv_var = outer_cat($(parts...))))
    end
    # add output variables and generate code
    outvars = [z; deriv_vars]
    push!(rg, :tuple, Espresso.genname(), Expr(:tuple, outvars...))
    rg = fuse_assigned(rg)
    evaluate!(rg)
    return generate_code(codegen, rg)
end
