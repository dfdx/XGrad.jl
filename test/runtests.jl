using XGrad
using ReverseDiff: GradientTape, GradientConfig, gradient, gradient!, compile
using Base.Test
# using BenchmarkTools

function test_compare(f; inputs...)
    vals = ([val for (name, val) in inputs]...)
    ctx = Dict()
    df = xdiff(f; ctx=ctx, inputs...)
    # compare_test runs in an older world age than the generated function
    # need to invoke the latest one in the test
    dvals = Base.invokelatest(df, vals...)
    dvals_a = [dvals...]

    f_tape = GradientTape(f, vals)
    compiled_f_tape = compile(f_tape)
    cfg = GradientConfig(vals)
    results = map(similar, vals)
    gradient!(results, compiled_f_tape, vals)
    results_a = [results...]
    @test isapprox(results_a, dvals_a[2:end]; atol=0.1)
end


logistic(x) = 1 ./ (1 + exp.(-x))
@diffrule logistic(x::Number) x (logistic(x) .* (1 .- logistic(x))) .* ds


include("aggr.jl")
include("linreg.jl")
include("ann.jl")
include("autoencoder.jl")
include("vae.jl")
include("others.jl")
include("destruct.jl")

