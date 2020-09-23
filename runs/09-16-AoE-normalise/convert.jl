using Distributed
nworkers() < 12 && addprocs(13 - nworkers())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-16-AoE-normalise"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_setup($configpath)

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"

event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))

pmap(event_paths) do path
    events_to_jld(path, joinpath(dir, "events"))
end
