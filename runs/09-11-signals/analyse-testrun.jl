using MaGeSigGen, StatsBase, Plots, Missings

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-11-signals"))
sigs = vcat((get_signals(file) for file in readdir(joinpath(dir, "signals"), join=true))...)

A = map(getA, skipmissing(sigs))

E = map(energy, skipmissing(sigs))

AoE = A ./ E

h = fit(Histogram, (E, AoE), nbins=(160, 40))
display(plot(h))
# display(plot(h, yaxis=:log10, seriestype=:step))
# savefig(joinpath(dir, "AoE.png"))
