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


## withindex

"""
Create an array similar to `x` with all zeros but one element at index I set to v
"""
function zeros_but(x::AbstractArray, v, I...)
    x = zeros(x)
    x[I...] = v
    return x
end


function zeros_but_grad(dy, x::AbstractArray, v, I...)
    
end
