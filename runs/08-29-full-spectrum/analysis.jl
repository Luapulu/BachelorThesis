using Plots, JLD, MaGeAnalysis
pyplot()

spectrum = JLD.load("runs/08-29-full-spectrum/spectrum.jld")["spectrum"]

println("Number of Events: $(sum(spectrum))")

# Plotting
low = getbin(500, 2998, (500, 3500))
high = getbin(3500, 2998, (500, 3500))
y = spectrum[low:high]
scatter(range(500, stop=3500, length=2998), y)
title!("Co-56 Spectrum")
yaxis!("Counts (log scale)", :log)
xaxis!("Deposited Energy in keV")
savefig("runs/08-29-full-spectrum/spectrum.svg")
