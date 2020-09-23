using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-24-big_siggen2"))
event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"

setup_path = joinpath(dir, "GWD6022_01ns.config")
init_setup(setup_path)

compton_regions = [
    1070, 1105, 1130, 1187, 1220, 1300, 1420, 1480,
    1550, 1600, 1700, 1790, 1900, 2000, 2140, 2300,
    2400, 2560, 2640, 2710, 2800, 2850, 2900, 2970,
    3100, 3300
]

dep_regions = [1577, 1988, 2180, 2232, 2251, 2429]

function event_filter(e)
    E = energy(e)
    incmptn = any(compton_regions .- 10 .< E .< compton_regions .+ 10)
    indep = any(dep_regions .- 3 .< E .< dep_regions .+ 3)
    return incmptn || indep
end

function get_eventpath(i)
    event_paths = sort(filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true)))
    return eventpaths[i]
end

function getrawsignals(filenum)
    path = get_eventpath(filenum)
    @info "Working on $(splitdir(path)[end])"

    filtered_events = Iterators.filter(event_filter, load_events(Event{Vector{Hit}}, path))

    sgnls = get_signals(SignalDict, filtered_events)

    save_path = joinpath(dir, "signals", split(splitdir(path)[end], '.')[1] * "_signals.jld")

    save(save_path, sgnls)
    @info "Saved signals to $(splitdir(save_path)[end])"
    return nothing
end
