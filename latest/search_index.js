var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Main",
    "title": "Main",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#XGrad.jl-Documentation-1",
    "page": "Main",
    "title": "XGrad.jl Documentation",
    "category": "section",
    "text": "CurrentModule = XGradXGrad.jl is a package for symbolic differentiation of expressions and functions in Julia. A 30 second example of its usage:# in file loss.jl\npredict(W, b, x) = W * x .+ b\nloss(W, b, x, y) = sum((predict(W, b, x) .- y).^2)\n\n# in REPL or another file\ninclude(\"loss.jl\")\nW = rand(3,4); b = rand(3); x = rand(4); y=rand(3)\ndloss = xdiff(loss; W=W, b=b, x=x, y=y)\ndloss_val, dloss!dW, dloss!db, dloss!dx, dloss!dy = dloss(W, b, x, y)See Tutorial for a more detailed introduction."
},

{
    "location": "tutorial.html#",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "page",
    "text": ""
},

{
    "location": "tutorial.html#Tutorial-1",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "section",
    "text": "XGrad.jl is a package for symbolic tensor differentiation that lets you automatically derive gradients of algebraic expressions or Julia functions with such expressions. Let's start right from examples."
},

{
    "location": "tutorial.html#Expression-differentiation-1",
    "page": "Tutorial",
    "title": "Expression differentiation",
    "category": "section",
    "text": "using XGrad\n\nxdiff(:(y = sum(W * x .+ b)); W=rand(3,4), x=rand(4), b=rand(3))In this code::(sum(W * x .+ b)) is an expression we want to differentiate\nW, x and b are example values, we need them to understand type of variables  in the expression (e.g. matrix vs. vector vs. scalar)The result of this call should look something like this:quote\n    tmp692 = @get_or_create(mem, :tmp692, Array(zeros(Float64, (3,))))\n    dy!dW = @get_or_create(mem, :dy!dW, Array(zeros(Float64, (3, 4))))\n    dy!dx = @get_or_create(mem, :dy!dx, Array(zeros(Float64, (4,))))\n    tmp698 = @get_or_create(mem, :tmp698, Array(zeros(Float64, (1, 4))))\n    tmp696 = @get_or_create(mem, :tmp696, Array(zeros(Float64, (3,))))\n    dy!db = @get_or_create(mem, :dy!db, Array(zeros(Float64, (3,))))\n    dy!dy = (Float64)(0.0)\n    y = (Float64)(0.0)\n    tmp700 = @get_or_create(mem, :tmp700, Array(zeros(Float64, (4, 3))))\n    tmp691 = @get_or_create(mem, :tmp691, Array(zeros(Float64, (3,))))\n    dy!dy = 1.0\n    tmp691 .= W * x\n    tmp692 .= tmp691 .+ b\n    tmp695 = size(tmp692)\n    tmp696 .= ones(tmp695)\n    dy!db = tmp696\n    dy!dx .= W' * (tmp696 .* dy!dy)\n    dy!dW .= dy!db * x'\n    y = sum(tmp692)\n    tmp702 = (y, dy!dW, dy!dx, dy!db)\nendFirst 10 lines (those starting with @get_or_create macro) are variable initialization. Don't worry about them right now, I will explain them later in this tutorial. The rest of the code calculates gradients of the result variable y w.r.t. input arguments, i.e. fracdydW, fracdydx and fracdydb. Note that the last expression is a tuple holding both - y and all the gradients. Differentiation requires computing y anyway, but you can use it or dismiss depending on your workflow.The generated code is somewhat ugly, but much more efficient than a naive one (which we will demonstrate in the following section). To make it run, you need first to define a mem::Dict variable. Try this:# since we will evaluate expression in global scope, we need to initialize variables first\nW = rand(3,4)\nx = rand(4)\nb = rand(3)\n\n# save derivative expression to a variable\ndex = xdiff(:(y = sum(W * x .+ b)); W=W, x=x, b=b)\n\n# define auxiliary variable `mem`\nmem = Dict()\neval(dex)which should give us something like:(4.528510092075925, [0.679471 0.727158 0.505823 0.209988; 0.679471 0.727158 0.505823 0.209988; 0.679471 0.727158 0.505823 0.209988], [0.919339, 1.61009, 1.74046, 1.9212], [1.0, 1.0, 1.0])Instead of efficient code you may want to get something more readable. Fortunately, XGrad's codegens are pluggable and you can easily switch default codegen to e.g. VectorCodeGen:ctx = Dict(:codegen => VectorCodeGen())\nxdiff(:(y = sum(W * x .+ b)); ctx=ctx, W=rand(3,4), x=rand(4), b=rand(3))this produces:quote\n    tmp796 = transpose(W)\n    dy!dy = 1.0\n    tmp794 = transpose(x)\n    tmp787 = W * x\n    tmp788 = tmp787 .+ b\n    tmp791 = size(tmp788)\n    tmp792 = ones(tmp791)\n    dy!db = tmp792 .* dy!dy\n    dy!dtmp787 = tmp792 .* dy!dy\n    dy!dx = tmp796 * dy!dtmp787\n    dy!dW = dy!dtmp787 * tmp794\n    y = sum(tmp788)\n    tmp798 = (y, dy!dW, dy!dx, dy!db)\nendSee more about different kinds of code generators in the corresponding section on the left [TODO]."
},

{
    "location": "tutorial.html#Function-differentiation-1",
    "page": "Tutorial",
    "title": "Function differentiation",
    "category": "section",
    "text": "In most optimization tasks you need not an expression, but a function for calculating derivatives. XGrad provides a convenient wrapper for it as well:# in file loss.jl\npredict(W, b, x) = W * x .+ b\n\nloss(W, b, x, y) = sum((predict(W, b, x) .- y)^2)\n\n# in REPL or another file\ninclude(\"loss.jl\")\nW = rand(3,4); b = rand(3); x = rand(4); y=rand(3)\ndloss = xdiff(loss; W=W, b=b, x=x, y=y)\ndloss(W, b, x, y)And voilà! We get a value of the same structure as in previous section:(3.531294775990527, [1.0199 1.09148 0.75925 0.315196; 1.92224 2.05715 1.43099 0.594062; 1.33645 1.43025 0.994905 0.413026], [1.50102, 2.82903, 1.9669], [2.20104, 3.07484, 3.31411, 4.33103], [-1.50102, -2.82903, -1.9669])note: Note\nXGrad works on Julia source code. When differentiating a function, XGrad first tries to read its source code from a file where it was defined (using Sugar.jl) and, if failed, to recover code from a lowered AST. The latter doesn't always work, so if you are working in REPL, it's a good idea to put functions to differentiate to a separate file and then include(...) it. Also see Code Discovery for some other rules."
},

{
    "location": "tutorial.html#Memory-buffers-1",
    "page": "Tutorial",
    "title": "Memory buffers",
    "category": "section",
    "text": "Remember a strange mem variable that we've seen in the Expression differentiation section? It turns out that significant portion of time for computing a derivative (as well as any numeric code with tensors) is spend on memory allocations. The obvious way to fix it is to use memory buffers and in-place functions. This is exactly the default behavior of XGrad.jl: it allocates buffers for all temporary variables in mem dictionary and rewrites expressions using BLAS, broadcasting and in-place assignments. To take advantage of this feature, just add a buffer of type  Dict{Any,Any}() as a last argument to the derivative function:mem = Dict()\ndloss(W, b, x, y, mem)If you take a look at the value of mem after this call, you will find a number of keys for each intermediate variable. Here's a full example:include(\"loss.jl\")\nW = rand(1000, 10_000); b = rand(1000); x = rand(10_000, 100); y=rand(1000)\ndloss = xdiff(loss; W=W, b=b, x=x, y=y)\n\nusing BenchmarkTools\n\n# without mem\n@btime dloss(W, b, x, y)\n# ==> 155.191 ms (84 allocations: 175.52 MiB)\n\n# with mem\nmem = Dict()\n@btime dloss(W, b, x, y, mem)\n# ==> 100.354 ms (26 allocations: 797.86 KiB)"
},

{
    "location": "tutorial.html#Struct-derivatives-1",
    "page": "Tutorial",
    "title": "Struct derivatives",
    "category": "section",
    "text": "So far our loss functions were pretty simple taking only a couple of parameters, but in real life machine learning models have many more of them. Copying a dozen of arguments all over the code quickly becomes a pain in the neck. To fight this issue, XGrad supports derivatives of (mutable) structs. Here's an example:# in file linear.jl\nmutable struct Linear\n    W::Matrix{Float64}\n    b::Vector{Float64}\nend\n\npredict(m::Linear, x) = m.W * x .+ m.b\n\nloss(m::Linear, x, y) = sum((predict(m, x) .- y).^2)\n\n\n## in REPL or another file\ninclude(\"linear.jl\")\nm = Linear(randn(3,4), randn(3))\nx = rand(4); y = rand(3)\ndloss = xdiff(loss; m=m, x=x, y=y)\ny_hat, dm, dx, dy = dloss(m, x, y)Just like with arrays in previous example, dm has the same type (Linear) and size of its fields (dm.W and dm.b) as original model, but holds gradients of paramaters instead of their values. If you are doing something like SGD on model parameters, you can then update the model like this:for fld in fieldnames(typeof(m))\n    theta = getfield(m, fld)\n    theta .-= getfield(dm, fld)\n    setfield!(m, fld, theta)\nend"
},

{
    "location": "tutorial.html#How-it-works-1",
    "page": "Tutorial",
    "title": "How it works",
    "category": "section",
    "text": "XGrad works similar to reverse-mode automatic differentiation, but operates on symbolic variables instead of actual values. If you are familiar with AD, you should already know most details, if not - don't worry, it's pretty simple. The main idea is to decompose an expression into a chain of some primitive function calls that we already know how to differentiate, assign the deriviative of the result a \"seed\" value of 1.0 and then propagate derivatives back to the input parameters. Here's an example.Let's say, you have an expression like this (where x is a plain number):z = exp(sin(x))It consists of 2 function calls that we write down, adding an intermediate variable y:y = sin(x)z = exp(y)We aim to go through all variables v_i and collect derivatives fracpartial zpartial v_i. The first variable is z itself. Since derivative of a variable w.r.t. itself is 1.0, we set:fracdzdz = 10The next step is to find the derivative of fracpartial zpartial y. We know that the derivative of exp(u) w.r.t. u is also exp(u). If there has been some accomulated derivative from variables later in the chain, we should also multiply by it:fracdzdy = fracd(exp(y))dy cdot fracdzdz = exp(y) cdot fracdzdzFinally, from math classes we know that the derivative of sin(u) is cos(u), so we add:fracdzdx = fracd(sin(x))dx cdot fracdzdy = cos(x) cdot fracdzdyThe full derivative expression thus looks like:fracdzdz = 10fracdzdy = exp(y) cdot fracdzdzfracdzdx = cos(x) cdot fracdzdyIn case of scalar-valued function of multiple variables (i.e. R^n rightarrow R, common in ML tasks) instead of \"derivative\" we say \"gradient\", but approach stays more or less the same."
},

{
    "location": "tutorial.html#Defining-your-own-primitives-1",
    "page": "Tutorial",
    "title": "Defining your own primitives",
    "category": "section",
    "text": "XGrad knows about most common primitive functions such as *, +, exp, etc., but there's certenly many more of them. Thus the library provides a @diffrule macro that lets you define your own differentiation rules. For example, provided a function for 2D convolution conv2d(x, w) and derivatives conv2d_grad_x(...) and conv2d_grad_w, you can add them like this@diffrule conv2d(x, w) x conv2d_grad_x(x, w, ds)\n@diffrule conv2d(x, w) w conv2d_grad_w(x, w, ds)where:conv2d(x, w) is a target function expression\nx and w are variables to differentiate w.r.t.\nconv2d_grad_x(...) and conv2d_grad_w(...) are derivative expression\nds is a previous gradient in the chain, e.g. if y = conv2d(x, w) and z is the  last variable of original expression, ds stands for gradient fracdzdy"
},

{
    "location": "codediscovery.html#",
    "page": "Code Discovery",
    "title": "Code Discovery",
    "category": "page",
    "text": ""
},

{
    "location": "codediscovery.html#Code-Discovery-1",
    "page": "Code Discovery",
    "title": "Code Discovery",
    "category": "section",
    "text": "one-linear function must have at least one empty line before header\nheader must take one line\nfirst line of a body must not be a comment"
},

]}
