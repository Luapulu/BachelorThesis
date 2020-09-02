## General ##

abstract type MaGeFile end
eltype(::Type{<:MaGeFile}) = MaGeEvent

isrootfile(path::AbstractString) = occursin(r".root.hits", path)

"""Get all .root.hits files in a directory"""
function magerootpaths(dirpath::AbstractString)
    [file for file in readdir(dirpath, join=true) if isrootfile(file)]
end

## Parsing MaGe .root.hits files ##

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

ishitline(line::AbstractString) = length(line) > 20 && line[end-8:end] == " physiDet"

function parsehit(line::AbstractString)::MaGeHit
    !ishitline(line) && error("cannot parse the following as hit: \"$line\"")
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

function parsemeta(line::AbstractString)
    intparse(str) = tryparse(Int, str)
    return map(intparse, split(line, " ", limit=3))
end

struct RootFile <: MaGeFile
    stream::IO
    hitvec::Vector{MaGeHit}
end
RootFile(io::IO, l::Int=1000) = RootFile(io, Vector{MaGeHit}(undef, l))
RootFile(f::AbstractString, l::Int=1000) = RootFile(open(f), l)

function readevent(file::RootFile)::MaGeEvent
    metaline = readline(file.stream)
    eventnum, hitcount, primarycount = parsemeta(metaline)

    if isnothing(eventnum) || isnothing(eventnum) || isnothing(eventnum)
        error("cannot parse the following as meta line: \"$metaline\"")
    end

    if length(file.hitvec) < hitcount
        append!(file.hitvec, Vector{MaGeHit}(undef, hitcount - length(file.hitvec)))
    end

    for i in 1:hitcount
        file.hitvec[i] = parsehit(readline(file.stream))
    end

    return MaGeEvent(file.hitvec[1:hitcount], eventnum, hitcount, primarycount)
end

Base.read(file::RootFile) = [event for event in file]
Base.close(file::RootFile) = close(file.stream)

IteratorSize(::Type{RootFile}) = Base.SizeUnknown()

function iterate(file::RootFile, state=nothing)
    eof(file.stream) && return (close(file); nothing)
    return (readevent(file), nothing)
end

## Parsing and writing .jld files ##

function save(e::MaGeEvent, path::AbstractString)
    save(path, e, compress=true)
end

function copytojld(filepath::AbstractString, resultpath::AbstractString)
    for event in getevents(filepath)
        save(event, resultpath)
    end
    nothing
end

## Loading events ##

function eachevent(f::AbstractString, file::MaGeFile, args...; kwargs...)
    return file(s, args..., kwargs...)
end
function eachevent(f::AbstractString, args...; kwargs...)
    isrootfile(f) ? RootFile(f, args...; kwargs...) :
    error("$f is not a valid filepath")
end
