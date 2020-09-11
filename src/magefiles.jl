## Detector config/setup ##

function get_detector_setup(configpath)::Struct_MJD_Siggen_Setup
    dir, f = splitdir(configpath)
    if !isdir(joinpath(dir, "fields"))
        fieldgen(configpath)
    end
    return signal_calc_init(configpath)
end

"""Convert to detector coordinates [mm]"""
function todetectorcoords(x::Float32, y::Float32, z::Float32, xtal_length::Float32)
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length
    return x, y, z
end

## MaGe .root.hits files ##

isrootfile(path::String) = occursin(r".root.hits$", path)

"""Get all .root.hits paths in a directory"""
function getdelimpaths(dirpath::String)
    [file for file in readdir(dirpath, join=true) if isrootfile(file)]
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

    x, y, z = todetectorcoords(x, y, z, xtal_length)

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
DelimFile(f::String, xtal_length::Float32) = DelimFile(Base.open(f), xtal_length)
DelimFile(f::String, setup::Struct_MJD_Siggen_Setup) = DelimFile(f, setup.xtal_length)

Base.IteratorSize(::Type{DelimFile}) = Base.SizeUnknown()
Base.eltype(::Type{DelimFile}) = MaGeEvent

function readevent(file::DelimFile)::MaGeEvent
    metaline = readline(file.stream)
    eventnum, hitcount, primarycount = parsemeta(metaline)

    if isnothing(eventnum) || isnothing(eventnum) || isnothing(eventnum)
        error("cannot parse the following as meta line: \"$metaline\"")
    end

    hitvec = Vector{MaGeHit}(undef, hitcount)
    for i in 1:hitcount
        hitvec[i] = parsehit(readline(file.stream), file.xtal_length)
    end

    return MaGeEvent(hitvec, eventnum, hitcount, primarycount)
end

Base.close(file::DelimFile) = close(file.stream)

function Base.iterate(file::DelimFile, state=nothing)
    eof(file.stream) && return (close(file); nothing)
    return (readevent(file), nothing)
end

eachevent(file::DelimFile) = file

## .jld2 files ##

isjld2file(path::String) = occursin(r".jld2$", path)

"""Get all .jld2 paths in a directory"""
function getjldpaths(dirpath::String)
    [file for file in readdir(dirpath, join=true) if isjld2file(file)]
end

function makejldpath(delimpath::String, destdir::String)
    dir, f = splitdir(delimpath)
    return joinpath(destdir, split(f, '.', limit=2)[1] * ".jld2")
end

struct JLD2File
    path::String
end

const JLD_LOCK = ReentrantLock()
function open(func::Function, f::JLD2File, mode="r")
    lock(JLD_LOCK) do
        jldopen(func, f.path, mode)
    end
end

function createjldfile(path::String)
    open(JLD2File(path), "w") do f
        JLD2.Group(f, "events")
    end
    nothing
end

function save_events(events::Vector{MaGeEvent}, path::String)
    open(JLD2File(path), "r+") do f
        eventgroup = f["events"]
        for e in events
            eventgroup[string(e.eventnum)] = e
        end
    end
    nothing
end

function delimtojld(sources::Vector{String}, destdir::String, setup::Struct_MJD_Siggen_Setup)
    pmap(sources) do path
        jldpath = makejldpath(path, destdir)
        createjldfile(jldpath)
        events = MaGeEvent[e for e in eachevent(DelimFile(path, setup))]
        save_events(events, jldpath)
    end
    nothing
end

function delimtojld(sourcedir::String, destdir::String, setup::Struct_MJD_Siggen_Setup)
    delimtojld(getdelimpaths(sourcedir), destdir, setup)
end

function eachevent(file::JLD2File)::Vector{MaGeEvent}
    events = open(file) do f
        eventgroup = f["events"]
        return MaGeEvent[eventgroup[k] for k in keys(eventgroup)]
    end
    return events
end

## Useful ##

function getfile(path::String, args...)
    isrootfile(path) ? DelimFile(path, args...) :
    isjld2file(path) ? JLD2File(path) :
    error("$path is not a valid filepath")
end

function filemap(func::Function, paths::Vector{String}; batch_size=1)
    files = [getfile(p) for p in paths]
    return pmap(func, files, batch_size=batch_size)
end
