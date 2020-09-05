## General ##

abstract type MaGeFile end
eltype(::Type{<:MaGeFile}) = MaGeEvent

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

struct DelimitedFile <: MaGeFile
    stream::IO
end
DelimitedFile(f::AbstractString) = DelimitedFile(open(f))

function readevent(file::DelimitedFile)::MaGeEvent
    metaline = readline(file.stream)
    eventnum, hitcount, primarycount = parsemeta(metaline)

    if isnothing(eventnum) || isnothing(eventnum) || isnothing(eventnum)
        error("cannot parse the following as meta line: \"$metaline\"")
    end

    hitvec = Vector{MaGeHit}(undef, hitcount)
    for i in 1:hitcount
        hitvec[i] = parsehit(readline(file.stream))
    end

    return MaGeEvent(hitvec, eventnum, hitcount, primarycount)
end

Base.read(file::DelimitedFile) = [event for event in file]
Base.close(file::DelimitedFile) = close(file.stream)

IteratorSize(::Type{DelimitedFile}) = Base.SizeUnknown()

function iterate(file::DelimitedFile, state=nothing)
    eof(file.stream) && return (close(file); nothing)
    return (readevent(file), nothing)
end

## Parsing and writing .jld2 files ##

const JLD_LOCK = ReentrantLock()

function makejldpath(roothitpath, destdir)
    dir, f = splitdir(roothitpath)
    return joinpath(destdir, splitext(splitext(f)[1])[1] * ".jld2")
end

function savetojld(source::AbstractString, dest::AbstractString)
    events = [event for event in DelimitedFile(source)]
    lock(JLD_LOCK) do
        jldopen(dest, "w") do file
            for event in events
                file[string(event.eventnum)] = event
            end
        end
    end
    nothing
end

function savetojld(sources::AbstractVector{<:AbstractString}, destdir::AbstractString; batch_size=1)
    save(source) = savetojld(source, makejldpath(source, destdir))
    pmap(save, sources, batch_size=batch_size)
    nothing
end

struct JLD2File <: MaGeFile
    events::AbstractVector{MaGeEvent}
    function JLD2File(path::AbstractString)
        events = lock(JLD_LOCK) do
            jldopen(path) do file
                return [file[k] for k in keys(file)]
            end
        end
        new(events)
    end
end
getindex(f::JLD2File, i::Int) = getindex(f.events, i)
iterate(f::JLD2File) = iterate(f.events)
iterate(f::JLD2File, state) = iterate(f.events, state)

## Convenience ##

isrootfile(path::AbstractString) = occursin(r".root.hits$", path)
isjld2file(path::AbstractString) = occursin(r".jld2$", path)

"""Get all .root.hits files in a directory"""
function magerootpaths(dirpath::AbstractString)
    [file for file in readdir(dirpath, join=true) if isrootfile(file)]
end

function jldpaths(dirpath::AbstractString)
    [file for file in readdir(dirpath, join=true) if isjld2file(file)]
end

function eachevent(f::AbstractString, file::MaGeFile, args...; kwargs...)
    return file(s, args..., kwargs...)
end

function eachevent(f::AbstractString, args...; kwargs...)
    isrootfile(f) ? DelimitedFile(f, args...; kwargs...) :
    isjld2file(f) ? JLD2File(f, args...; kwargs...) :
    error("$f is not a valid filepath")
end
