using Distributed
nworkers() < 12 && addprocs(12 - nworkers())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere Pkg.instantiate()
@everywhere using MaGeAnalysis

dir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "runs", "09-11-signals"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_setup($configpath)

@time eventstojld(
    "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM",
    joinpath(dir, events)
)
