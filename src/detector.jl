## Detector config/setup ##

SETUP = nothing

function init_detector_setup(configpath)::Struct_MJD_Siggen_Setup
    dir, f = splitdir(configpath)
    if !isdir(joinpath(dir, "fields"))
        fieldgen(configpath)
    end

    global SETUP = mktemp() do path, io
        redirect_stdout(io) do
            signal_calc_init(configpath)
        end
    end

    return SETUP
end

"""Convert to detector coordinates [mm]"""
function todetectorcoords(x::Float32, y::Float32, z::Float32, xtal_length::Float32)
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length
    return x, y, z
end
