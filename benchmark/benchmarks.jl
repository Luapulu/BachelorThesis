using BenchmarkTools, MaGeAnalysis, Profile

dir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "test"))
jldpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld2")
jldpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.jld2")

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
init_setup(configpath)

get_signals(e -> e.fileindex <= 1, [jldpath1, jldpath2], joinpath(dir, "signals"))

Profile.clear()

@profile @time get_signals(e -> e.fileindex <= 5, [jldpath1, jldpath2], joinpath(dir, "signals"))

Profile.print(mincount=100)
