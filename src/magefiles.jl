add_format(format"MAGE", (), ".root.hits")

ishitline(line::AbstractString) = length(line) > 20 && line[end-8:end] == " physiDet"

struct MaGeRoot
    filepath::AbstractString
    maxhitcount::Int # Used for preallocation.
    expanding::Bool
end
length(f::MaGeRoot) = length(filter(line -> !ishitline(line), readlines(f.filepath)))

function iterate(iter::MaGeRoot, state=(eachline(iter.filepath), Vector{MaGeHit}(undef, iter.maxhitcount)))
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

const MaGeJLD = Base.Generator{JLD.JldFile,typeof(FileIO.load)}

function getmagepaths(dirpath::AbstractString, filepattern::Regex)
    [file for file in readdir(dirpath, join=true) if occursin(filepattern, file)]
end
getmagepaths(dirpath::AbstractString) = getmagepaths(dirpath, r".root.hits$")

getevents(filepath::AbstractString, maxhitcount::Int) = MaGeRoot(filepath, maxhitcount, false)
function getevents(filepath::AbstractString)
    occursin(r".root.hits$", filepath) ? MaGeRoot(filepath, 1000, true) :
    occursin(r".jld$", filepath) ? (load(filepath, id) for id in names(jldopen(filepath, "r"))) :
    error("$filepath must end with .root.hits or .jld")
end

function filemap(func, filepaths::AbstractArray{String}; batch_size=1)
    return pmap(func, getevents(f) for f in filepaths, batch_size=batch_size)
end

save(e::MaGeEvent, path::AbstractString; id=string(uuid4())) = save(path, id, e, compress=true)

function copytojld(filepath::AbstractString, resultpath::AbstractString)
    for event in getevents(filepath)
        save(event, resultpath)
    end
    nothing
end
