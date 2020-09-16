## MaGe .root.hits files ##

function getparseranges(line::String)
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

ishitline(line::String) = length(line) > 20 && line[end-8:end] == " physiDet"

function parsehit(line::String, xtal_length::Float32)::MaGeHit
    !ishitline(line) && error("cannot parse \"$line\" as hit")
    ranges = getparseranges(line)
    x =             parse(Float32, line[ranges[3]])
    y =             parse(Float32, line[ranges[1]])
    z =             parse(Float32, line[ranges[2]])
    E =             parse(Float32, line[ranges[4]])
    t =             parse(Float32, line[ranges[5]])
    particleid =    parse(Int32, line[ranges[6]])
    trackid =       parse(Int32, line[ranges[7]])
    trackparentid = parse(Int32, line[ranges[8]])

    x, y, z = to_detector_coords(x, y, z, xtal_length)

    return MaGeHit(x, y, z, E, t, particleid, trackid, trackparentid)
end

function parsemeta(line::String)
    intparse(str) = tryparse(Int, str)
    return map(intparse, split(line, " ", limit=3))
end

struct EventFile
    stream::IO
    xtal_length::Float32
end
EventFile(f::String) = EventFile(Base.open(f), SETUP.xtal_length)

Base.IteratorSize(::Type{EventFile}) = Base.SizeUnknown()
Base.eltype(::Type{EventFile}) = MaGeEvent

function readevent(file::EventFile, fileindex::Int)::MaGeEvent
    metaline = readline(file.stream)
    eventnum, hitcount, primarycount = parsemeta(metaline)

    if isnothing(eventnum) || isnothing(eventnum) || isnothing(eventnum)
        error("cannot parse the following as meta line: \"$metaline\"")
    end

    hitvec = Vector{MaGeHit}(undef, hitcount)
    for i in 1:hitcount
        hitvec[i] = parsehit(readline(file.stream), file.xtal_length)
    end

    return MaGeEvent(hitvec, eventnum, hitcount, primarycount, fileindex)
end

Base.close(file::EventFile) = close(file.stream)

function Base.iterate(file::EventFile, i=1)
    eof(file.stream) && return (close(file); nothing)
    return (readevent(file, i), i + 1)
end

## .jld2 files ##

const JLD_LOCK = ReentrantLock()
function openjld2(func::Function, path::AbstractString, mode="r")
    lock(JLD_LOCK) do
        jldopen(func, path, mode)
    end
end

function savejld2(o, name::String, path::AbstractString)
    openjld2(path, "a+") do f
        f[name] = o
    end
    nothing
end

function loadjld2(name::String, path::AbstractString)
    openjld2(path, "r") do f
        return f[name]
    end
end
