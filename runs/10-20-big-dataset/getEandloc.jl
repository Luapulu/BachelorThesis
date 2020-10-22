using MaGeSigGen, MJDSigGen, MaGe, Statistics

const dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "10-20-big-dataset"))
const event_dir = "/lfs/l3/gerda/ga53sog/Montecarlo/results/GWD6022_Co56_side50cm/DM/"

isdir(joinpath(dir, "tier2")) || mkdir(joinpath(dir, "tier2"))

setup_path = joinpath(dir, "GWD6022_01ns.config")
const setup = MJDSigGen.signal_calc_init(setup_path)

const compton_regions = [
    1070, 1105, 1130, 1187, 1220, 1300, 1420, 1480,
    1550, 1600, 1700, 1790, 1900, 2000, 2140, 2300,
    2400, 2560, 2640, 2710, 2800, 2850, 2900, 2970,
    3100, 3300
]

const dep_regions = [1577, 1988, 2180, 2232, 2251, 2429]

function event_filter(e)
    E = energy(e)
    incmptn = any(compton_regions .- 10 .< E .< compton_regions .+ 10)
    indep = any(dep_regions .- 3 .< E .< dep_regions .+ 3)
    return incmptn || indep
end

const event_paths = sort(filter(p -> occursin(r".root.hits$", p), readdir(event_dir)))

function getEandlocs(filenum)
    path = joinpath(event_dir, event_paths[filenum])
    @info "Working on $(splitdir(path)[end])"

    filtered_events = Iterators.filter(event_filter, MaGe.loadstreaming(path))
    events = [todetcoords!(e, setup) for e in filtered_events]

    Es = map(energy, events)
    locs = vcat(map(e -> location(first(hits(e))), events)...)
    xEs = map(e -> mean(map(h -> h.x * h.E, hits(e))), events)
    yEs = map(e -> mean(map(h -> h.y * h.E, hits(e))), events)
    zEs = map(e -> mean(map(h -> h.z * h.E, hits(e))), events)
    enums = map(eventnum, events)

    save_path = joinpath(dir, "tier2", split(splitdir(path)[end], '.')[1] * "_tier2.jld")
    save(save_path, "Es", Es, "locs", locs, "xEs", xEs, "yEs", yEs, "zEs", zEs, "enums", enums)

    @info "Saved tier2 data to $(splitdir(save_path)[end])"

    nothing
end

function getEandlocs(firstnum, lastnum)
    for num in firstnum:lastnum
        getEandlocs(num)
    end
end
