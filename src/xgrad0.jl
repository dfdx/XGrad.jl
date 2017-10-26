
## xgrad0.jl - dynamic cache for xdiff

DERIV_CACHE = Dict{Any,Any}()


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
