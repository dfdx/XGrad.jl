
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
    evaluate!(g)
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
    g.ctx[:loss] = z
    dzdz_var = deriv_name(z, z)
    dg = ExGraph(:($dzdz_var = 1.0))
    for nd in reverse(g.tape)
        rev_step!(g, dg, nd)
    end
    outvars = [deriv_name(z, varname(nd)) for nd in g.tape if isa(nd, ExNode{:input})]
    return fuse_assigned(dg; outvars=outvars)
end


function _xdiff(g::AbstractExGraph)
    forward_pass!(g)
    dg = reverse_pass!(g)
    return dg
end




"""
Differentiate expression w.r.t. its inputs
"""
function xdiff(ex; ctx=Dict(), inputs...)
    g = ExGraph(ex; inputs...)
    dg = _xdiff(g)
    rg = cat(g, dg)
    outvars = unshift!([deriv_name(g.ctx[:loss], var) for (var, _) in inputs], varname(g[end]))
    push!(rg, :tuple, Espresso.genname(), Expr(:tuple, outvars...))
    rg = topsort(rg)
    infer_deriv_size!(rg)  # need to know size to evaluate things like `dz!dx[i] = 1.0`
    evaluate!(rg)
    codegen = @get(ctx, :codegen, BufCodeGen())
    return generate_code(codegen, rg)
end



"""
Differentiate function w.r.t. its inputs
"""
function xdiff(f::Function; ctx=Dict(), inputs...)
    ctx = to_context(ctx)
    types = ([typeof(val) for (name, val) in inputs]...)
    args, ex = func_expr(f, types)
    flat_args, ex, st = destruct(args, types, ex)
    ex = sanitize(ex)
    flat_inputs = destruct_inputs(inputs)    
    dex = xdiff(ex; ctx=ctx, flat_inputs...)
    ctx[:dex] = dex
    mod = get(ctx, :mod, current_module())
    name = Espresso.genname("$(func_name(f))_deriv_")
    flat_types = [top_type(val) for (name, val) in flat_inputs]
    typed_flat_args = [:($a::$t) for (a, t) in zip(flat_args, flat_types)]    
    # function with additional argument `mem`
    fn_ex_mem = make_func_expr(name, [typed_flat_args; :mem], [], dex)
    fn = eval(mod, fn_ex_mem)
    # function with kw argument `mem=Dict()`
    fn_ex_mem_kw = make_func_expr(name, typed_flat_args, [:mem => Dict()], dex)
    eval(mod, fn_ex_mem_kw)
    if any(isstruct, types)
        # preparations for model adapter
        struct_types = [isstruct(t) ? t : top_type(t) for t in types]
        typed_args = [:($a::$t) for (a, t) in zip(args, struct_types)]
        rev_st = Dict(v => k for (k, v) in st)
        model_args = [haskey(rev_st, a) ? rev_st[a] : a for a in flat_args]
        # model adapter: with additional `mem`
        model_fn_ex_mem = :($name($(typed_args...), mem) =
                            $name($(model_args...), mem)) |> sanitize
        eval(mod, model_fn_ex_mem)
        # model adapter: with kw argument `mem=Dict()`
        model_fn_ex_kw = :($name($(typed_args...); mem=Dict()) =
                           $name($(model_args...); mem=Dict())) |> sanitize
        eval(mod, model_fn_ex_kw)
    end
    return fn
end
