using Distributed
nworkers() < 12 && addprocs(13 - nworkers())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-16-big-siggen"))

configpath = joinpath(dir, "GWD6022_01ns.config")
fieldgen(configpath)
@everywhere init_detector($configpath)

event_dir = ???
event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))

!isdir(joinpath(dir, "events")) && mkdir(joinpath(dir, "events"))

pmap(event_paths) do path
    events_to_jld(path, joinpath(dir, "events"))
end
