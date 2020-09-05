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

function makejldpath(roothitpath, destdir)
    dir, f = splitdir(roothitpath)
    return joinpath(destdir, splitext(splitext(f)[1])[1] * ".jld2")
end

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

function savetojld(sources::AbstractVector{<:AbstractString}, destdir::AbstractString; batch_size=1)
    save(source) = savetojld(source, makejldpath(source, destdir))
    pmap(save, sources, batch_size=batch_size)
end

struct JLD2File <: MaGeFile
    file::JLD2.JLDFile
    keys::AbstractVector{String}
    checkhash::Bool
end
JLD2File(file::JLD2.JLDFile; checkhash::Bool=false) = JLD2File(file, keys(file), checkhash)
JLD2File(path::AbstractString; kwargs...) = JLD2File(jldopen(path); kwargs...)
keys(f::JLD2File) = f.keys
getindex(f::JLD2File, name::AbstractString) = getindex(f.file, name)
getindex(f::JLD2File, i::Int) = getindex(f, keys(f)[i])
length(f::JLD2File) = length(keys(f))
function iterate(file::JLD2File, state=1)
    state > length(file) && return nothing
    k = keys(file)[state]
    e = file[k]
    file.checkhash && string(hash(e)) != k && error("data has been altered or corrupted!")
    return e, state + 1
end

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
