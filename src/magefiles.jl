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
DelimFile(f::String, setup::Struct_MJD_Siggen_Setup=SETUP) = DelimFile(f, setup.xtal_length)

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

eachevent(path::String, setup::Struct_MJD_Siggen_Setup=SETUP) = DelimFile(path, setup)

## .jld2 files ##

struct JLD2File
    path::String
end

const JLD_LOCK = ReentrantLock()
function Base.open(func::Function, f::JLD2File, mode="r")
    lock(JLD_LOCK) do
        jldopen(func, f.path, mode)
    end
end

function save(o, name::String, path::String)
    open(JLD2File(path), "w") do f
        f[name] = o
    end
    nothing
end

save(events::Vector{MaGeEvent}, path::String) = save(events, "events", path)

function getevents(path::String)
    open(JLD2File(path)) do f
        return f["events"]
    end
end

## filemap ##

function filemap(func::Function, paths::Vector{String}; batch_size=1)
    pmap(paths, batch_size=batch_size) do path
        @debug "Worker $(myid()) working on file $(splitdir(path)[2])"
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

function eventstojld(sources::Vector{String}, destdir::String, setup::Struct_MJD_Siggen_Setup=SETUP)
    filemap(sources) do path
        outpath = makejldpath(path, destdir)
        save(MaGeEvent[e for e in eachevent(path, setup)], outpath)
        @info "Worker $(myid()) wrote file $(splitdir(path)[2]) to $outpath"
    end
    nothing
end

function eventstojld(sourcedir::String, destdir::String, setup::Struct_MJD_Siggen_Setup=SETUP)
    eventstojld(getdelimpaths(sourcedir), destdir, setup)
end
