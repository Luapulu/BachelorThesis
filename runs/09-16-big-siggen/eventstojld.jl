using Distributed
worker_num = 10
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-16-big-siggen"))

configpath = joinpath(dir, "GWD6022_01ns.config")
@everywhere init_detector($configpath)

event_paths = ????

!isdir(joinpath(dir, "events")) && mkdir(joinpath(dir, "events"))

@distributed for path in event_paths
    save_path = joinpath(dir, "events", split(splitdir(path)[end], ".", limit=2)[1] * ".jld2")
    save_events(MaGeEvent[e for e in eachevent(eventpath)], save_path)
    nothing
end
