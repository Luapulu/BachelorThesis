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

isrootfile(path::AbstractString) = occursin(r".root.hits", path)

abstract type MaGeReader end
eltype(::Type{<:MaGeReader}) = MaGeEvent

struct RootReader <: MaGeReader
    stream::IO
    hitvec::Vector{MaGeHit}
end
RootReader(io::IO, l::Int=1000) = RootReader(io, Vector{MaGeHit}(undef, l))
RootReader(f::AbstractString, l::Int=1000) = RootReader(open(f), l)

function Base.read(reader::RootReader)::MaGeEvent
    metaline = readline(reader.stream)
    eventnum, hitcount, primarycount = parsemeta(metaline)

    if isnothing(eventnum) || isnothing(eventnum) || isnothing(eventnum)
        error("cannot parse the following as meta line: \"$metaline\"")
    end

    if length(reader.hitvec) < hitcount
        append!(reader.hitvec, Vector{MaGeHit}(undef, hitcount - length(reader.hitvec)))
    end

    for i in 1:hitcount
        reader.hitvec[i] = parsehit(readline(reader.stream))
    end

    return MaGeEvent(reader.hitvec[1:hitcount], eventnum, hitcount, primarycount)
end

Base.close(reader::RootReader) = close(reader.stream)

IteratorSize(::Type{RootReader}) = Base.SizeUnknown()

function iterate(reader::RootReader, state=nothing)
    eof(reader.stream) && return (close(reader); nothing)
    return (read(reader), nothing)
end

function eachevent(f::AbstractString, reader::MaGeReader, args...; kwargs...)
    return reader(s, args..., kwargs...)
end
function eachevent(f::AbstractString, args...; kwargs...)
    isrootfile(f) ? RootReader(f, args...; kwargs...) :
    error("$f is not a valid filepath")
end

function magerootpaths(dirpath::AbstractString)
    [file for file in readdir(dirpath, join=true) if isrootfile(file)]
end

function filemap(func, filepaths::AbstractArray{<:AbstractString}; batch_size=1)
    return pmap(func, filepaths, batch_size=batch_size)
end

save(e::MaGeEvent, path::AbstractString; id=string(uuid4())) = save(path, id, e, compress=true)

function copytojld(filepath::AbstractString, resultpath::AbstractString)
    for event in getevents(filepath)
        save(event, resultpath)
    end
    nothing
end
