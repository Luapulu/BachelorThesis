using MaGeSigGen, MJDSigGen, MaGe

const dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-24-big-siggen2"))
const event_dir = "/lfs/l3/gerda/ga53sog/Montecarlo/results/GWD6022_Co56_side50cm/DM/"

isdir(joinpath(dir, "signals")) || mkdir(joinpath(dir, "signals"))

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

function getrawsignals(filenum)
    path = abspatch(event_paths[i])
    @info "Working on $(splitdir(path)[end])"

    sgnls = get_signals(SignalDict, setup, MaGe.loadstreaming(path))

    save_path = joinpath(dir, "signals", split(splitdir(path)[end], '.')[1] * "_signals.jld")

    save(save_path, sgnls)

    @info "Saved signals to $(splitdir(save_path)[end])"

    nothing
end

function getrawsignals(firstnum, lastnum)
    for num in firstnum:lastnum
        getrawsignals(num)
    end
end
