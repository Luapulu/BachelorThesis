module MaGe

import Base:iterate
import Base:size, getindex, show

using Base.Iterators: take

export MaGeHit, MaGeEvent, MaGeFile
export geteventfiles, eachevent


struct MaGeFile
    filepath::AbstractString
    maxhitcount::Int # Used for preallocation.
    expanding::Bool
end
eachevent(filepath) = MaGeFile(filepath, 200, true)
eachevent(filepath, maxhitcount) = MaGeFile(filepath, maxhitcount, false)

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

struct MaGeEvent <: AbstractVector{MaGeHit}
    hits::AbstractVector{MaGeHit}
    eventnum::Int
    hitcount::Int
    primarycount::Int
    function MaGeEvent(hits, eventnum, hitcount, primarycount)
        if length(hits) != hitcount
            throw(ArgumentError("hitcount $hitcount must equal number of hits $(length(hits))"))
        end
        return new(hits, eventnum, hitcount, primarycount)
    end
end
size(E::MaGeEvent) = (E.hitcount,)
getindex(E::MaGeEvent, i::Int) = getindex(E.hits, i)
show(io::IO, E::MaGeEvent) = dump(E, maxdepth=1)


function geteventfiles(dirpath::AbstractString, filepattern::Regex)
    [file for file in readdir(dirpath, join=true) if occursin(filepattern, file)]
end

ishitline(line::AbstractString) = length(line) > 30

function iterate(iter::MaGeFile, state=(eachline(iter.filepath), Vector{MaGeHit}(undef, iter.maxhitcount)))
    line_iter, hitvec = state

    next = iterate(line_iter)
    next === nothing && return nothing

    metaline, _ = next
    ishitline(metaline) && error("Expected meta line but got \"$metaline\"")
    eventnum, hitcount, primarycount = parsemetaline(metaline)

    if iter.expanding && length(hitvec) < hitcount
        hitvec = Vector{MaGeHit}(undef, hitcount)
    end

    i = 0
    for hitline in take(line_iter, hitcount)
        i += 1
        hitvec[i] = parsehit(hitline)
    end

    event = MaGeEvent(hitvec[1:i], eventnum, hitcount, primarycount)
    return event, (line_iter, hitvec)
end

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
    intparse(str) = parse(Int, str)
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

    return MaGeHit(x, y, z, E, t, particleid, trackid, trackparentid)
end

"""
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

# convert to detector coordinates [mm]
xtal_length = 1
x = 10(x + 200)
y = 10y
z = -10z + 0.5xtal_length

"""

end
