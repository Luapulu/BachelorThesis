import Base: iterate


struct MaGeHitIter
    files::AbstractVector{AbstractString}
end
MaGeHitIter(filepath::AbstractString) = MaGeHitIter([filepath])

function MaGeHitIter(dirpath::AbstractString, filepattern::Regex)
    MaGeHitIter([file for file in readdir(dirpath, join=true) if occursin(filepattern, file)])
end

function iterate(iter::MaGeHitIter, state)
    rowvector, fileindex, rowindex = state
    if rowindex > length(rowvector)
        rowindex = 1
        fileindex += 1
        fileindex > length(iter.files) && return nothing
        rowvector = readlines(iter.files[fileindex])
    end
    return rowvector[rowindex], (rowvector, fileindex, rowindex+1)
end
iterate(iter::MaGeHitIter) = iterate(iter::MaGeHitIter, (AbstractString[], 0, 1))

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

function parserow(row::AbstractString, xtal_length=1)
    stringarr = split(row)
    length(stringarr) !== 9 && return row

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
