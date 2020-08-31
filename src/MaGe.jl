module MaGe

import Base:iterate
import Base:size, getindex
using Base.Iterators: take, drop

struct MaGeFile
    filepath::AbstractString
    maxhitcount::Int32 # Used for preallocation.
end

const MaGeEventVec = Vector{MaGeHit}

struct MaGeEvent <: AbstractVector{MaGeHit}
    hits::AbstractVector{MaGeHit}
    eventnum::Int32
    hitcount::Int32
    primarycount::Int32
    function MaGeEvent(hits, eventnum, hitcount, primarycount)
        length(hits) != hitcount && error("hitcount must equal length of hit array")
        return new(hits, eventnum, hitcount, primarycount)
    end
end
size(E::MaGeEvent) = (E.hitcount,)
getindex(E::MaGeEvent, i::Int) = getindex(E.hits, i)


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

getevents(filepath::AbstractString) = MaGeFile(filepath)

function iterate(iter::MaGeFile, state)
    line_iter, hitvec = state
    metaline, _ = iterate(line_iter)
    eventnum, hitcount, primarycount = parsemetaline(metaline)
    for (i, hitline) in enumerate(take(line_iter, hitcount))
        hitvec[i] = parsehit(hitline)
    end
    event = MaGeEvent(hitvec[1:hitcount], eventnum, hitcount, primarycount)
    new_line_iter = drop(line_iter, hitcount)
    return event, (new_line_iter, hitvec)
end

ishitline(line::AbstractString) = length(line) > 30

function getparseranges(line::AbstractString)
    ranges = Vector{UnitRange{Int32}}(undef, 8)
    start = 1
    for i in 1:8
        r = findnext(" ", line, start)
        ending, next = prevind(line, first(r)), nextind(line,last(r))
        ranges[i] = start:ending
        start = next
    end
    return ranges
end

function parsemetaline(line::AbstractString)
    intparse(str) = parse(Int32, str)
    return map(intparse, split(line, " ", limit=3))
end

function parsehit(line::AbstractString)::MaGeHit
    ranges = getparseranges(line)
    x =             parse(Float32, line[ranges[3]])
    y =             parse(Float32, line[ranges[1]])
    z =             parse(Float32, line[ranges[2]])
    E =             parse(Float32, line[ranges[4]])
    t =             parse(Float32, line[ranges[5]])
    particleid =    parse(Int32, line[ranges[6]])
    trackid =       parse(Int32, line[ranges[7]])
    trackparentid = parse(Int32, line[ranges[8]])

    # convert to detector coordinates [mm]
    xtal_length = 1
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length

    return MaGeHit(x, y, z, E, t, particleid, trackid, trackparentid)
end

function cleanhitfile(filepath::AbstractString)
    return filter(ishitline, readlines(filepath))
end

function iterate(iter::MaGeEvent, line_iter)
    next = iterate(line_iter)
    next === nothing && return nothing
    line, _ = next
    while !ishitline(line)
        next = iterate(line_iter)
        next === nothing && return nothing
        line, _ = next
    end
    return parsehit(line), line_iter
end

function iterate(iter::MaGeEvent)
    return iterate(iter, (eachline(iter.filepath), Vector{UnitRange{Int32}}(undef, 8)))
end

calcenergy(event::MaGeEventVec) = sum(hit.E for hit in event)
calcenergy(event::MaGeEvent) = sum(hit.E for hit in event)
calcenergy(filepath::AbstractString) = calcenergy(MaGeEvent(filepath))

end
