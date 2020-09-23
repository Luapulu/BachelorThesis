using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere begin
    import Pkg
    Pkg.activate(".")
    using MaGeSigGen
end

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-23-siggen2"))

setup_path = joinpath(dir, "GWD6022_01ns.config")
@everywhere init_setup($setup_path)

@everywhere function event_filter(e)
    regions = [
        1070, 1105, 1130, 1187, 1220, 1300, 1420, 1480,
        1550, 1600, 1700, 1790, 1900, 2000, 2140, 2300,
        2400, 2560, 2640, 2710, 2800, 2850, 2900, 2970,
        3100, 3300
    ]
    return any(r - 10 < energy(e) < r + 10 for r in regions)
end

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"
event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))

!isdir(joinpath(dir, "signals")) && mkdir(joinpath(dir, "signals"))

pmap(event_paths) do epath
    @info "Worker $(myid()) working on $(splitdir(epath)[end])"

    filtered_events = Iterators.filter(event_filter, load_events(Event{Vector{Hit}}, epath))

    sgnls = get_signals(SignalDict, filtered_events)

    save_path = joinpath(dir, "signals", split(splitdir(epath)[end], '.')[1] * "_signals.jld")

    save(save_path, sgnls)
end
