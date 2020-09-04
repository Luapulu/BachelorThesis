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
    hitvec::Vector{MaGeHit}
end
DelimitedFile(io::IO, l::Int=1000) = DelimitedFile(io, Vector{MaGeHit}(undef, l))
DelimitedFile(f::AbstractString, l::Int=1000) = DelimitedFile(open(f), l)

function readevent(file::DelimitedFile)::MaGeEvent
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

Base.read(file::DelimitedFile) = [event for event in file]
Base.close(file::DelimitedFile) = close(file.stream)

IteratorSize(::Type{DelimitedFile}) = Base.SizeUnknown()

function iterate(file::DelimitedFile, state=nothing)
    eof(file.stream) && return (close(file); nothing)
    return (readevent(file), nothing)
end

## Parsing and writing .jld2 files ##

function savetojld(source::AbstractString, dest::AbstractString)
    sl = Threads.SpinLock()
    jldopen(dest, "w") do file
        for event in DelimitedFile(source)
            lock(sl)
            try
                file[string(hash(event))] = event
            finally
                unlock(sl)
            end
        end
    end
    nothing
end

function savetojld(sources::AbstractVector{<:AbstractString}, dest::AbstractString; batch_size=1)
    pmap(source->savetojld(source, dest), sources, batch_size=batch_size)
end

struct JldFile <: MaGeFile
    file::JLD.JldFile
    keys::AbstractVector{String}
    checkhash::Bool
end
JldFile(file::JLD.JldFile; checkhash::Bool=false) = JldFile(file, names(file), checkhash)
JldFile(path::AbstractString; kwargs...) = JldFile(jldopen(path); kwargs...)
keys(f::JldFile) = f.keys
getindex(f::JldFile, name::AbstractString) = read(getindex(f.file, name))
getindex(f::JldFile, i::Int) = getindex(f, keys(f)[i])
length(f::JldFile) = length(keys(f))
function iterate(file::JldFile, state=1)
    state > length(file) && return nothing
    e = file[state]
    file.checkhash && string(hash(e)) != keys(file)[state] && error("data has been altered or corrupted!")
    return file[state], state + 1
end

## Convenience ##

isrootfile(path::AbstractString) = occursin(r".root.hits$", path)
isjld2file(path::AbstractString) = occursin(r".jld2$", path)

"""Get all .root.hits files in a directory"""
function magerootpaths(dirpath::AbstractString)
    [file for file in readdir(dirpath, join=true) if isrootfile(file)]
end

function eachevent(f::AbstractString, file::MaGeFile, args...; kwargs...)
    return file(s, args..., kwargs...)
end

function eachevent(f::AbstractString, args...; kwargs...)
    isrootfile(f) ? DelimitedFile(f, args...; kwargs...) :
    isjld2file(f) ? JldFile(f, args...; kwargs...) :
    error("$f is not a valid filepath")
end
