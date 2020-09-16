## Detector config/setup ##

function init_detector(configpath)
    global SETUP
    if !isdefined(MaGeSigGen, :SETUP)
        mktemp() do path, io
            redirect_stdout(io) do
                SETUP = signal_calc_init(configpath)
                Base.Libc.flush_cstdio()
            end
        end
    else
        error("Attempted to redefine detector setup")
    end

    @info "Initialised detector setup with $configpath"
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
