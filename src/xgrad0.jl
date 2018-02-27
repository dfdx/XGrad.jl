
## xgrad0.jl - dynamic cache for xdiff

DERIV_CACHE = Dict{Any,Any}()
const DGRAD_CACHE = Dict{Any,Any}()


getsize(x::AbstractArray) = size(x)
getsize(x::Number) = ()

function getsize(x)
    if isstruct(x)
        sz_arr = []
        for fld in fieldnames(typeof(x))
            val = getfield(x, fld)
            push!(sz_arr, getsize(val))
        end
        return (sz_arr...)
    else
        return size(x)
    end
end


"""
Calculate gradient of a function at specified inputs, cache the derivative.

    loss(w, x, y) = sum(w * x .- y)
    val, dw, dx, dy = xgrad(loss; w=rand(2,3), x=rand(3,4), y=rand(2))

`xgrad` also accepts context `ctx::Dict{}` and cache `mem::Dict{Any,Any}`.

See also: `xdiff`.
"""
function xgrad(f::Function; ctx=Dict(), mem=Dict(), inputs...)
    vals = [v for (k, v) in inputs]
    types = [typeof(v) for v in vals]
    sizes = [getsize(v) for v in vals]
    key = (f, types)
    if haskey(DERIV_CACHE, key)
        df, old_sizes = DERIV_CACHE[key]
        if sizes != old_sizes
            # new input sizes - recompile and clean up buffers
            # println("recompiling for new sizes and cleaning up memory")
            df = xdiff(f; ctx=copy(ctx), inputs...)
            DERIV_CACHE[key] = (df, sizes)
            for k in keys(mem)
                delete!(mem, k)
            end
        end
    else
        # println("compiling derivative")
        # if derivative function isn't compiled yet, do it
        # use copy of context in order not to pollute the passed one
        df = xdiff(f; ctx=copy(ctx), inputs...)
        DERIV_CACHE[key] = (df, sizes)
    end
    dvals = Base.invokelatest(df, vals..., mem)
    return dvals
end



function _dgrad(f::Function, args...)
    g = tracked_exgraph(f, args...)
    key = graph_hash(g)   # TODO: handle different sizes
    if haskey(DGRAD_CACHE, key)
        return DGRAD_CACHE[key]
    else
        g, dg = _xdiff(g)
        rg = cat(g, dg)
        inputs = [getvar(nd) => getvalue(nd) for nd in g if isa(nd, ExNode{:input})]
        outvars = unshift!([deriv_name(g.ctx[:loss], var) for (var, _) in inputs], varname(g[end]))
        push!(rg, :tuple, Espresso.genname(), Expr(:tuple, outvars...))
        rg = topsort(rg)
        infer_deriv_size!(rg) # do we still need this? can we replace rsizes with actual sizes?
        evaluate!(rg)
        codegen = autoselect_codegen(inputs)
        dex = generate_code(codegen, rg)
        # generate function
        mod = current_module()
        name = Espresso.genname("$(func_name(f))_deriv_")
        input_vars = [var for (var, val) in inputs]
        types = [typeof(val) for (var, val) in inputs]
        typed_args = [:($a::$t) for (a, t) in zip(input_vars, map(top_type, types))]
        # function with kw argument `mem=Dict()`
        fn_ex_mem_kw = make_func_expr(name, typed_args, [:mem => :(Dict{Any,Any}())], dex)
        dfn = eval(mod, fn_ex_mem_kw)
        return dfn
    end
end


"""
    dgrad(f::Function)

Experimental: dynamic differentiation

"""
function dgrad(f::Function)
    (args...) -> begin
        dfn = _dgrad(f, args...)
        Base.invokelatest(dfn, args...)[2]
    end
end
