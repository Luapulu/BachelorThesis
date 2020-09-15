## MaGe .root.hits files ##

isdelimfile(path::String) = occursin(r".root.hits$", path)

"""Get all .root.hits paths in a directory"""
function getdelimpaths(dirpath::String)
    [file for file in readdir(dirpath, join=true) if isdelimfile(file)]
end

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

struct DelimFile
    stream::IO
    xtal_length::Float32
end
DelimFile(f::String) = DelimFile(Base.open(f), SETUP.xtal_length)

Base.IteratorSize(::Type{DelimFile}) = Base.SizeUnknown()
Base.eltype(::Type{DelimFile}) = MaGeEvent

function readevent(file::DelimFile, fileindex::Int)::MaGeEvent
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

Base.close(file::DelimFile) = close(file.stream)

function Base.iterate(file::DelimFile, i=1)
    eof(file.stream) && return (close(file); nothing)
    return (readevent(file, i), i + 1)
end

eachevent(path::String) = DelimFile(path)

## .jld2 files ##

struct JLD2File
    path::String
end

const JLD_LOCK = ReentrantLock()
function openjld2(func::Function, f::JLD2File, mode="r")
    lock(JLD_LOCK) do
        jldopen(func, f.path, mode)
    end
end

function savejld2(o, name::String, path::String)
    openjld2(JLD2File(path), "w") do f
        f[name] = o
    end
    nothing
end

function loadjld2(name::String, path::String)
    openjld2(JLD2File(path)) do f
        return f[name]
    end
end

save_events(events::Vector{MaGeEvent}, path::String) = savejld2(events, "events", path)
get_events(path::String) = loadjld2("events", path)

## filemap ##

function filemap(func::Function, paths::Vector{String}; batch_size=1)
    pmap(paths, batch_size=batch_size) do path
        @info "Worker $(myid()) now on file $(splitdir(path)[2])"
        return func(path)
    end
end

function filemap(func::Function, dir::String; batch_size=1)
    return filemap(func, readdir(dir, join=true); batch_size=batch_size)
end

function makejldpath(delimpath::String, destdir::String)
    dir, f = splitdir(delimpath)
    return joinpath(destdir, split(f, '.', limit=2)[1] * ".jld2")
end

function eventstojld(sources::Vector{String}, destdir::String)
    filemap(sources) do path
        outpath = makejldpath(path, destdir)
        save_events(MaGeEvent[e for e in eachevent(path)], outpath)
        @info "Worker $(myid()) wrote events from $(splitdir(path)[2])\n to $outpath"
    end
    nothing
end

function eventstojld(sourcedir::String, destdir::String)
    eventstojld(getdelimpaths(sourcedir), destdir)
end
