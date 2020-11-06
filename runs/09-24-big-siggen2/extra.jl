using MaGeSigGen, MJDSigGen, MaGe

const dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-24-big-siggen2"))
const event_dir = "/lfs/l3/gerda/ga53sog/Montecarlo/results/GWD6022_Co56_side50cm/DM/"

isdir(joinpath(dir, "extra")) || mkdir(joinpath(dir, "extra"))

setup_path = joinpath(dir, "GWD6022_01ns.config")
const setup = MJDSigGen.signal_calc_init(setup_path)

const dep_regions = [1577, 1988, 2180, 2232, 2251, 2429]

function event_filter(e)
    E = energy(e)
    lower = any(dep_regions .- 10 .< E .<= dep_regions .- 3)
    upper = any(dep_regions .+ 3 .<= E .< dep_regions .+ 10)
    return lower || upper
end

const event_paths = sort(filter(p -> occursin(r".root.hits$", p), readdir(event_dir)))

function getrawsignals(filenum)
    path = joinpath(event_dir, event_paths[filenum])
    @info "Working on $(splitdir(path)[end])"

    filtered_events = Iterators.filter(event_filter, MaGe.loadstreaming(path))
    events = (todetcoords!(e, setup) for e in filtered_events)

    sgnls = get_signals(SignalDict, setup, events)

    save_path = joinpath(dir, "extra", split(splitdir(path)[end], '.')[1] * "_signals.jld")

    save(save_path, sgnls)

    @info "Saved signals to $(splitdir(save_path)[end])"

    nothing
end

function getrawsignals(firstnum, lastnum)
    for num in firstnum:lastnum
        getrawsignals(num)
    end
end
