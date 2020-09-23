using Distributed
nprocs() < 3 && addprocs(3 - nprocs())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere Pkg.instantiate()
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-11-signals"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_setup($configpath)

jldpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld2")
jldpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.jld2")

filemap([jldpath1, jldpath2]) do path
    events = get_events(path)
    sigs = get_signals(filter(e -> 800 < energy(e) < 4000, events), length(events))
    d, f = splitdir(path)
    savepath = joinpath(d, splitext(f)[1] * "signals" * ".jld2")
    save(sigs, "9-14", savepath)
end
