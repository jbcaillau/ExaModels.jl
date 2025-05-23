# # Accelerations
# One of the key features of ExaModels.jl is being able to evaluate derivatives either on multi-threaded CPUs or GPU accelerators. Currently, GPU acceleration is only tested for NVIDIA GPUs. If you'd like to use multi-threaded CPU acceleration, start julia with
# ```
# $ julia -t 4 # using 4 threads
# ```
# Also, if you're using NVIDIA GPUs, make sure to have installed appropriate drivers.

# Let's say that our CPU code is as follows.
function luksan_vlcek_obj(x, i)
    return 100 * (x[i-1]^2 - x[i])^2 + (x[i-1] - 1)^2
end

function luksan_vlcek_con(x, i)
    return 3x[i+1]^3 + 2 * x[i+2] - 5 + sin(x[i+1] - x[i+2])sin(x[i+1] + x[i+2]) + 4x[i+1] -
           x[i]exp(x[i] - x[i+1]) - 3
end

function luksan_vlcek_x0(i)
    return mod(i, 2) == 1 ? -1.2 : 1.0
end

function luksan_vlcek_model(N)

    c = ExaCore()
    x = variable(c, N; start = (luksan_vlcek_x0(i) for i = 1:N))
    constraint(c, luksan_vlcek_con(x, i) for i = 1:(N-2))
    objective(c, luksan_vlcek_obj(x, i) for i = 2:N)

    return ExaModel(c)
end

# Now we simply modify this by
function luksan_vlcek_model(N, backend = nothing)

    c = ExaCore(; backend = backend) # specify the backend
    x = variable(c, N; start = (luksan_vlcek_x0(i) for i = 1:N))
    constraint(c, luksan_vlcek_con(x, i) for i = 1:(N-2))
    objective(c, luksan_vlcek_obj(x, i) for i = 2:N)

    return ExaModel(c)
end


# The acceleration can be done simply by specifying the backend. In particular, for multi-threaded CPUs,
using ExaModels, NLPModelsIpopt, KernelAbstractions

m = luksan_vlcek_model(10, CPU())
ipopt(m)

# For NVIDIA GPUs, we can use `CUDABackend`. However, currently, there are not many optimization solvers that are capable of solving problems on GPUs. The only option right now is using [MadNLP.jl](https://github.com/MadNLP/MadNLP.jl). To use this, first install
# ```julia
# import Pkg; Pkg.add("MadNLPGPU")
# ```
# Then, we can run:
# ```julia
# using CUDA, MadNLPGPU
# 
# m = luksan_vlcek_model(10, CUDABackend())
# madnlp(m)
# ```

# In the case we have arrays for the data, what we need to do is to simply convert the array types to the corresponding device array types. In particular,

function cuda_luksan_vlcek_model(N)
    c = ExaCore(; backend = CUDABackend())
    d1 = CuArray(1:(N-2))
    d2 = CuArray(2:N)
    d3 = CuArray([luksan_vlcek_x0(i) for i = 1:N])

    x = variable(c, N; start = d3)
    constraint(c, luksan_vlcek_con(x, i) for i in d1)
    objective(c, luksan_vlcek_obj(x, i) for i in d2)

    return ExaModel(c)
end

# ```julia
# m = cuda_luksan_vlcek_model(10)
# madnlp(m)
# ```
