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
        error("attempted to redefine detector setup")
    end

    @info "Initialised detector setup with $configpath"
    return nothing
end

outside_detector(location::NTuple{3, T})  where {T} = outside_detector(SETUP, location)

"""Convert to detector coordinates [mm]"""
function to_detector_coords(x::Real, y::Real, z::Real; xtal_length::Real = SETUP.xtal_length)
    return 10(z + 200), 10x, -10y + 0.5xtal_length
end
