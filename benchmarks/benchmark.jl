using MaGeAnalysis, Profile, BenchmarkTools

dir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "test", "testfiles"))
delimpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.root.hits")
delimpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.root.hits")
jldpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld2")
jldpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.jld2")

delimtojld([delimpath1, delimpath2], dir)

filemap([jldpath1, jldpath2]) do f
        mean(calcenergy, eachevent(f))
end

@time for _ in 1:500; filemap([jldpath1, jldpath2]) do f
        mean(calcenergy, eachevent(f))
end; end

# Profile.print()
Profile.clear()

rm(jldpath1)
rm(jldpath2)
