
## deriv.jl - derivative of a single ExNode

const DIFF_PHS = Set([:x, :y, :z])


function without_types(pat)
    rpat = copy(pat)
    for i=2:length(rpat.args)
        rpat.args[i] = isa(rpat.args[i],  Expr) ? rpat.args[i].args[1] : rpat.args[i]
    end
    return rpat
end


function get_arg_names(pat)
    return [isa(a, Expr) ? a.args[1] : a for a in pat.args[2:end]]
end

function get_arg_types(pat)
    return [isa(a, Expr) ? eval(Base, a.args[2]) : Any for a in pat.args[2:end]]
end


function match_rule(rule, ex, dep_vals, idx)
    tpat, (vname, rpat) = rule
    vidx = findfirst(get_arg_names(tpat), vname)
    if idx != vidx
        return Nullable{Any}()
    end
    dep_types = get_arg_types(tpat)
    if length(dep_vals) != length(dep_types) ||
        !all(isa(v, t) for (v, t) in zip(dep_vals, dep_types))
        return Nullable{Any}()
    end
    pat = without_types(tpat)
    if !matchingex(pat, ex; phs=DIFF_PHS)
        return Nullable{Any}()
    else
        return Nullable{Any}(pat => rpat)
    end
end


function deriv(ex, dep_vals, idx::Int)
    rex = nothing
    for rule in DIFF_RULES
        m = match_rule(rule, ex, dep_vals, idx)
        if !isnull(m)
            pat, rpat = get(m)
            rex = rewrite(ex, pat, rpat; phs=DIFF_PHS)
            break
        end
    end
    if rex == nothing
        error("Can't find differentiation rule for $ex at $idx " *
              "with types $(map(typeof, dep_vals))")
    end
    return rex
end
