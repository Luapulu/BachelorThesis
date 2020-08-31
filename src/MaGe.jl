module MaGe

import Base:iterate
import Base:size, getindex, show, length

using Base.Iterators: take
using Distributed

export MaGeHit, MaGeEvent, MaGeFile
export geteventfiles, eachevent, filemap, calcenergy, calcfrequencies


struct MaGeFile
    filepath::AbstractString
    maxhitcount::Int # Used for preallocation.
    expanding::Bool
end
length(f::MaGeFile) = length(filter(line -> length(line) < 30, readlines(f.filepath)))

eachevent(filepath::AbstractString) = MaGeFile(filepath, 500, true)
eachevent(filepath::AbstractString, maxhitcount::Int) = MaGeFile(filepath, maxhitcount, false)

function filemap(func, filepaths::AbstractArray{String})
    return pmap(func, eachevent(f) for f in filepaths)
end

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

calcenergy(event::MaGeEvent) = sum(hit.E for hit in event)

function getbin(val, bins::Int, limits::Tuple{T, T}) where T <: Real
    lower, upper = limits
    if val < lower
        val = lower
    elseif val > upper
        val = upper
    end
    step = (upper - lower) / (bins - 1)
    return Int64(fld(val - lower, step) + 1)
end

function calcfrequencies(func, f::MaGeFile, bins::Int, limits::Tuple{T, T}) where T <: Real
    freq = Vector{Int64}(zeros(bins))
    for event in f
        freq[getbin(func(event), bins, limits)] += 1
    end
    return freq
end

"""
# convert to detector coordinates [mm]
xtal_length = 1
x = 10(x + 200)
y = 10y
z = -10z + 0.5xtal_length

"""

end
