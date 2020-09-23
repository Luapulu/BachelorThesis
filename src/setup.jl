## Detector config/setup ##

const SigGenSetup = Struct_MJD_Siggen_Setup

function group_effects_off!(stp::SigGenSetup)
	stp.energy = 0
	stp.charge_cloud_size = 0
	stp.use_diffusion = 0
	stp.use_acceleration = 0
	stp.use_repulsion = 0
	return stp
end

function init_setup(setup_path)
    global SETUP
    if !isdefined(MaGeSigGen, :SETUP)
        mktemp() do path, io
            redirect_stdout(io) do
                SETUP = group_effects_off!(signal_calc_init(setup_path))
                Base.Libc.flush_cstdio()
            end
        end
    else
        error("cannot redefine detector setup")
    end

    @info "Initialised detector setup with $setup_path"
    return nothing
end

setup() = SETUP::SigGenSetup

function with_group_effects(f::Function, E::Real, ch_cld_size::Real, args...; kwargs...)
	try
		setup().energy = E
		setup().charge_cloud_size = ch_cld_size
		setup().use_diffusion = 1
		setup().use_acceleration = 1
		setup().use_repulsion = 1

		return f(args...; kwargs...)
	finally
		group_effects_off!(setup())
	end
end

function outside_detector(location::NTuple{3, T})  where {T}
	outside_detector(setup(), location)
end

"""Convert to detector coordinates [mm]"""
function to_detector_coords(x::Real, y::Real, z::Real; xtal_length::Real = setup().xtal_length)
    return 10(z + 200), 10x, -10y + 0.5xtal_length
end
