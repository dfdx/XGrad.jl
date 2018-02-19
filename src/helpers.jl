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
