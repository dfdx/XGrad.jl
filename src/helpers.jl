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
