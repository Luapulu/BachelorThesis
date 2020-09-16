using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-16-AoE-normalise"))

configpath = joinpath(dir, "GWD6022_01ns.config")
@everywhere init_detector($configpath)

@everywhere function event_filter(e::MaGeEvent)
    regions = [
        1070, 1105, 1130, 1187, 1220, 1300, 1420, 1480,
        1550, 1600, 1700, 1790, 1900, 2000, 2140, 2300,
        2400, 2560, 2640, 2710, 2800, 2850, 2900, 2970,
        3100, 3300
    ]
    return any(r - 20 < energy(e) < r + 20 for r in regions)
end

pmap(readdir(joinpath(dir, "events"), join=true)) do path
    save_path = joinpath(dir, "signals", splitdir(path)[end])
    isfile(save_path) && return nothing
    @info "Worker $(myid()) working on $(splitdir(path)[end])"
    events = get_events(path)
    filtered_events = filter(event_filter, events)
    signals = get_signals(filtered_events, length(events))
    save_signals(signals, save_path)
    @info "Worker $(myid()) saved signals"
    nothing
end
