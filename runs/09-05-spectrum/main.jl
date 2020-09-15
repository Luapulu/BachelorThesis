result = sum(filemap(CO56_JLD_FILES) do f
      getcounts(energy, eachevent(f), 3500, (500, 4000))
end)

jldopen("runs/09-05-spectrum/spectrum.jld2", "w") do file
      write(file, "spectrum", result)
end
