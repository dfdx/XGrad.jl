## helpers.jl - exported functions used in generated code

function ungetindex!(dx::AbstractArray, x::AbstractArray, ds, i...)
    dx[[i...]] .= ds
    return dx
end

function ungetindex!(dx::AbstractArray, x::AbstractArray, ds, i::AbstractArray{Int})
    dx[i] .= ds
    return dx
end


function ungetindex(x::AbstractArray, ds, i...)
    dx = zeros(x)
    return ungetindex!(dx, x, ds, i...)
end


@require StaticArrays begin

    import StaticArrays: StaticArray, SVector, SMatrix

    function ungetindex(sx::StaticArray, ds, i...)
        # make ordinary array of the same size
        x = Array{eltype(sx)}(size(sx))
        copy!(x, sx)
        dx = ungetindex(x, ds, i...)
        # TODO: what is a generic constructor for SArray?
        if ndims(sx) == 1
            return SVector(dx...)
        elseif ndims(sx) == 2
            return SMatrix(dx...)
        else
            error("Don't know how to create $(ndims(sx))-dimensional StaticArray")
        end
    end
end


function outer_cat(xs::AbstractArray{T,N}...) where {T,N}
    res = Array{T, N+1}(size(xs[1])..., length(xs))
    colons = (Colon() for i in 1:N)
    for i in eachindex(xs)
        res[colons..., i] = xs[i]
    end
    return res
end


function outer_cat(xs::Number...)
    return [xs...]
end
