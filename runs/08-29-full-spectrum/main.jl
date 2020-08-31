@time result = sum(filemap(CO56_HIT_FILES[1:8]) do file
    calcfrequencies(calcenergy, file, 3000, (500, 3500))
end)

save("spectrum.jld", "spectrum", result)
