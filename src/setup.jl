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

function with_group_effects!(
	f::Function, stp::SigGenSetup, E::Real,
	ch_cld_size::Real, args...; kwargs...
)
	try
		stp.energy = E
		stp.charge_cloud_size = ch_cld_size
		stp.use_diffusion = 1
		stp.use_acceleration = 1
		stp.use_repulsion = 1

		return f(stp, args...; kwargs...)
	finally
		group_effects_off!(stp)
	end
end

"""Convert to detector coordinates [mm]"""
function todetcoords(x::Real, y::Real, z::Real, xtal_length::Real)
    return 10(z + 200), 10x, -10y + 0.5xtal_length
end

todetcoords(x::Real, y::Real, z::Real, stp::SigGenSetup) =
	todetcoords(x, y, z, stp.xtal_length)

function todetcoords(h::Hit, stp::SigGenSetup)
	x, y, z = todetcoords(location(h)..., stp)
	return Hit(x, y, z, energy(h), time(h), particleid(h), trackid(h), trackparentid(h))
end

function todetcoords!(e::Event{Vector{Hit}}, stp::SigGenSetup)
	for i in 1:length(e)
		hits(e)[i] = todetcoords(hits(e)[i], stp)
	end
	return e
end
