
## xdiff.jl - forward and reverse passes of symbolic differentiation

## utils

function extend_deriv!(dg::ExGraph, dzdx_v::Symbol, dzdx::Any)
    subderivs = find_related(dg, dzdx_v)
    pos = indexof(dg, dzdx_v)
    if isempty(subderivs)
        # first split
        dzdx_ex_1 = getexpr(dg[dzdx_v])
        dzdx_ex_2 = dzdx
        dzdx_v_1 = Symbol("$(dzdx_v)__1")
        dzdx_v_2 = Symbol("$(dzdx_v)__2")
        sub_dg = ExGraph()
        parse!(sub_dg, :($dzdx_v_1 = $dzdx_ex_1))
        parse!(sub_dg, :($dzdx_v_2 = $dzdx_ex_2))
        parse!(sub_dg, :($dzdx_v = $dzdx_v_1 .+ $dzdx_v_2))
        sub_dg = fuse_assigned(sub_dg)
        new_nodes = sub_dg.tape
    else
        # dg already contains subderivatives for dzdx_v
        last_idx = parse(Int, split(subderivs[end] |> String, "__")[end])
        dzdx_v_last = Symbol("$(dzdx_v)__$(last_idx + 1)")
        prev_dzdx_ex = getexpr(dg[dzdx_v])
        sub_dg = ExGraph()
        parse!(sub_dg, :($dzdx_v_last = $dzdx))
        parse!(sub_dg, :($dzdx_v = $prev_dzdx_ex .+ $dzdx_v_last))
        sub_dg = fuse_assigned(sub_dg)
        new_nodes = sub_dg.tape
    end
    delete!(dg, pos)
    insert!(dg, pos, new_nodes)
    return dg
end


## forward pass

function forward_pass!(g::ExGraph)
    evaluate!(g) # to get types of all variables and find correct functions to inline
    known_funcs = Set(rule[1].args[1] for rule in DIFF_RULES)
    graph_funcs = Set(getexpr(nd).args[1] for nd in g if isa(nd, ExNode{:call}))
    unknown_funcs = setdiff(graph_funcs, known_funcs)
    unknown_func_vars = Set(varname(nd) for nd in g
                            if isa(nd, ExNode{:call}) && getexpr(nd).args[1] in unknown_funcs)
    g = inline_nodes(g, unknown_func_vars)
    evaluate!(g; force=true)
    return g
end

## reverse pass

"""
Perform one step of reverse pass. Add derivatives of output variable w.r.t.
node's dependenices to derivative graph.
"""
function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:(=)})
    y = varname(nd)
    x = dependencies(nd)[1]
    dzdx_vname = deriv_name(z, x)
    # parse!(dg, :($))
    error("Not implemented yet")

end


function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:constant})
    # do nothing
end


function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:input})
    # do nothing
end


function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:field})
    ex = getexpr(nd)
    m_name = ex.args[1]
    fld_name = ex.args[2].value
    dzdx_v = deriv_name(g.ctx[:loss], m_name)
    if haskey(dg, dzdx_v)
        m_nd = dg[dzdx_v]
        kw = @get_or_create(m_nd.meta, :kw, Dict())
        dzdy_v = deriv_name(g.ctx[:loss], varname(nd))
        kw[fld_name] = dzdy_v
    else
        m_nd = ExNode{:ctor}(dzdx_v, :(__construct($m_name)))
        kw = @get_or_create(m_nd.meta, :kw, Dict())
        dzdy_v = deriv_name(g.ctx[:loss], varname(nd))
        kw[fld_name] = dzdy_v
        push!(dg, m_nd)
    end
end


function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:ref})
    ex = getexpr(nd)
    base_name = ex.args[1]
    base_val = getvalue(g[base_name])
    idx = ex.args[2]
    dzdx_v = deriv_name(g.ctx[:loss], base_name)
    if !haskey(dg, dzdx_v)
        @assert(isa(base_val, Tuple), "Currently only indexing of tuples is supported, " *
                "but got $(typeof(base_val))")
        tuple_ex = Expr(:tuple, (:_ for i=1:length(base_val))...)
        push!(dg, :tuple, dzdx_v, tuple_ex)
    end
    dzdx_nd = dg[dzdx_v]
    dzdx_ex = getexpr(dzdx_nd)
    dzdy_v = deriv_name(g.ctx[:loss], varname(nd))
    dzdx_ex.args[idx] = dzdy_v
end


function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:tuple})
    z = g.ctx[:loss]
    dzdy_v = deriv_name(z, varname(nd))
    dzdy_nd = dg[dzdy_v]
    dzdy_ex = getexpr(dzdy_nd)
    for (i, x) in enumerate(dependencies(nd))
        # map x derivative directly to the component in a tuple
        # remove_unused() should then remove tuple altogether
        # alternative way would be to generate expression like :(dz!dx = dz!dt[i])
        dzdx_v = deriv_name(z, x)
        dzdx_ex = dzdy_ex.args[i]
        parse!(dg, :($dzdx_v = $dzdx_ex))
    end
end



function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:call})
    y = varname(nd)
    z = g.ctx[:loss]
    dzdy_v = deriv_name(z, y)
    cg = cat(g, dg)
    ex = getexpr(nd)
    dep_vals = [getvalue(g[x]) for x in dependencies(nd)]
    for (i, x) in enumerate(dependencies(nd))
        xnd = g[x]
        if isa(xnd, ExNode{:constant})
            # don't clog dg with unnesessary derivs
            continue
        end
        dydx = deriv(ex, dep_vals, i)
        dzdx = subs(dydx, Dict(:ds => dzdy_v))
        # dzdx = expand_const(cg, dzdx) |> simplify
        dzdx_v = deriv_name(z, x)
        if haskey(dg, dzdx_v)
            extend_deriv!(dg, dzdx_v, dzdx)
        else
            parse!(dg, :($dzdx_v = $dzdx))
        end
    end
end


function rev_step!(g::ExGraph, dg::ExGraph, nd::ExNode{:bcast})
    y = varname(nd)
    z = g.ctx[:loss]
    dzdy_v = deriv_name(z, y)
    cg = cat(g, dg)
    ex = bcast_to_call(getexpr(nd))
    dep_vals = [getvalue(g[x])[1] for x in dependencies(nd)]
    for (i, x) in enumerate(dependencies(nd))
        xnd = g[x]
        if isa(xnd, ExNode{:constant})
            # don't clog dg with unnesessary derivs
            continue
        end
        dydx = deriv(ex, dep_vals, i)
        dzdx = subs(dydx, Dict(:ds => dzdy_v))
        dzdx = calls_to_bcast(dzdx)
        # dzdx = expand_const(cg, dzdx) |> simplify
        dzdx_v = deriv_name(z, x)
        if haskey(dg, dzdx_v)
            extend_deriv!(dg, dzdx_v, dzdx)
        else
            parse!(dg, :($dzdx_v = $dzdx))
        end
    end
end


function reverse_pass!(g::ExGraph)
    z = @get_or_create(g.ctx, :loss, varname(g.tape[end]))
    dzdz_var = deriv_name(z, z)
    seed = @get_or_create(g.ctx, :seed, 1.0)
    dg = ExGraph(:($dzdz_var = $seed))
    for nd in reverse(g.tape)
        rev_step!(g, dg, nd)
    end
    outvars = [deriv_name(z, varname(nd)) for nd in g.tape if isa(nd, ExNode{:input})]
    return fuse_assigned(dg; outvars=outvars)
end


function _xdiff(g::AbstractExGraph)
    g = forward_pass!(g)
    dg = reverse_pass!(g)
    return g, dg
end


iscuarray(v) = startswith(string(typeof(v)), "CuArray")

# currently CuArrays can't be used directly in xdiff, so instead we convert them
# to ordinary Arrays, find gradients and use CuCodeGen to generate code for CUDA
# if inputs are not CuArrays, this function effectively does nothing
function unconvert_cuarrays(inputs)
    return [iscuarray(v) ? k => convert(Array, v) : k => v for (k, v) in inputs]
end



"""
Differentiate expression w.r.t. its inputs
"""
function xdiff(ex; ctx=Dict(), inputs...)
    ctx = to_context(ctx)
    codegen = @get(ctx, :codegen, autoselect_codegen(inputs))
    inputs = unconvert_cuarrays(inputs)
    g = ExGraph(ex; ctx=ctx, inputs...)
    g, dg = _xdiff(g)
    rg = cat(g, dg)
    outvars = unshift!([deriv_name(g.ctx[:loss], var) for (var, _) in inputs], varname(g[end]))
    push!(rg, :tuple, Espresso.genname(), Expr(:tuple, outvars...))
    rg = topsort(rg)
    infer_deriv_size!(rg)  # need to know size to evaluate things like `dz!dx[i] = 1.0`
    evaluate!(rg)
    return generate_code(codegen, rg)
end



"""
Differentiate function w.r.t. its inputs
"""
function xdiff(f::Function; ctx=Dict(), inputs...)
    ctx = to_context(ctx)
    types = ([typeof(val) for (name, val) in inputs]...)
    args, ex = func_expr(f, types)
    ex = sanitize(ex)
    dex = xdiff(ex; ctx=ctx, inputs...)
    ctx[:dex] = dex
    mod = get(ctx, :mod, current_module())
    name = Espresso.genname("$(func_name(f))_deriv_")
    typed_args = [:($a::$t) for (a, t) in zip(args, map(top_type, types))]
    # function with additional argument `mem`
    fn_ex_mem = make_func_expr(name, [typed_args; :mem], [], dex)
    fn = eval(mod, fn_ex_mem)
    # function with kw argument `mem=Dict()`
    fn_ex_mem_kw = make_func_expr(name, typed_args, [:mem => :(Dict{Any,Any}())], dex)
    eval(mod, fn_ex_mem_kw)
    return fn
end
