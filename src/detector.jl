## Detector config/setup ##

SETUP = nothing

function init_setup(configpath)
    dir, f = splitdir(configpath)
    if !isdir(joinpath(dir, "fields"))
        fieldgen(configpath)
    end

    global SETUP
    if isnothing(SETUP)
        SETUP = signal_calc_init(configpath)
    else
        @warn "Attempted to reinitialise setup"
    end

    return nothing
end

outside_detector(location::NTuple{3, T} where T) = outside_detector(SETUP, location)

"""Convert to detector coordinates [mm]"""
function to_detector_coords(x::Float32, y::Float32, z::Float32, xtal_length::Float32)
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length
    return x, y, z
end
