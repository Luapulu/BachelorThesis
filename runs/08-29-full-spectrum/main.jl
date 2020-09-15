@time result = sum(filemap(CO56_HIT_FILES) do file
    getcounts(energy, file, 3000, (500, 3500))
end)

JLD.save("runs/08-29-full-spectrum/spectrum.jld", "spectrum", result)
