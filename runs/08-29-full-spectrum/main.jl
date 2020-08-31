@everywhere include("runs/boilerplate.jl")

@time result = sum(filemap(CO56_HIT_FILES[1:8]) do file
    calcfrequencies(calcenergy, file, 3000, (800, 4000))
end)

println(result)
