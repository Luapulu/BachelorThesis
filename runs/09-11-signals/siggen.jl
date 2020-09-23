using Distributed
nworkers() < 16 && addprocs(17 - nprocs())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere Pkg.instantiate()
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-11-signals"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_setup($configpath)

get_signals(
    e -> 800 < energy(e) < 4000,
    joinpath(dir, "events"),
    joinpath(dir, "signals")
)
