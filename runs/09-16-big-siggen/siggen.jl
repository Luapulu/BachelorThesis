using Distributed
worker_num = 200
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-16-big-siggen"))

configpath = joinpath(dir, "GWD6022_01ns.config")
@everywhere init_detector($configpath)

!isdir(joinpath(dir, "signals")) && mkdir(joinpath(dir, "signals"))

pmap(readdir(joinpath(dir, "events"), join=true)) do path
    @info "Worker $(myid()) working on $(splitdir(path)[end])"
    events = getevents(path)
    filtered_events = filter(e -> (800 < energy(e) < 4000), events)
    signals = get_signals(filtered_events, length(events))
    save_signals(signals, joinpath(dir, "signals", splitdir(path)[end]))
    nothing
end
