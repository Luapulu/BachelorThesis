using MaGeAnalysis, JLD2, Plots

result = jldopen("runs/09-05-spectrum/spectrum.jld2") do file
      read(file, "spectrum")
end

plot(result)
