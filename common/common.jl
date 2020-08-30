struct MaGeHit
    x::Float32
    y::Float32
    z::Float32
    E::Float32
    t::Float32
    particleid::Int32
    trackid::Int32
    trackparentid::Int32
end

function geteventfiles(dirpath::AbstractString, filepattern::Regex)
    [file for file in readdir(dirpath, join=true) if occursin(filepattern, file)]
end

function parserow(row::AbstractString, xtal_length::Real)
    stringarr = split(row)
    length(stringarr) != 9 && return nothing

    x =             parse(Float32, stringarr[3])
    y =             parse(Float32, stringarr[1])
    z =             parse(Float32, stringarr[2])
    E =             parse(Float32, stringarr[4])
    t =             parse(Float32, stringarr[5])
    particleid =    parse(Int32, stringarr[6])
    trackid =       parse(Int32, stringarr[7])
    trackparentid = parse(Int32, stringarr[8])

    # convert to detector coordinates [mm]
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length

    return MaGeHit(x, y, z, E, t, particleid, trackid, trackparentid)
end

function parseevent(filepath::AbstractString, xtal_length::Real)::Vector{MaGeHit}
    rowarr = readlines(filepath)
    hitcount = split(pop!(rowarr, 1), " ")[2]
    hitarr = Vector{MaGeHit}(undef, hitcount)
    hitindex = 1
    for (rowindex, row) in enumerate(rowarr)
        hit = parserow(rowarr[i])
        hit == nothing && continue
        hitarr[hitindex] = hit
        hitindex += 1
    end
    return hitarr
end
