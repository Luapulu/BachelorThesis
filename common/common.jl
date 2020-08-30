import Base:iterate

struct MaGeHit
    x::Float32
    y::Float32
    z::Float32
    E::Float32
    t::Float32
    particleid::Int32
    trackid::Int32
    trackparentid::Int32
end

const MaGeEventVec = Vector{MaGeHit}

function geteventfiles(dirpath::AbstractString, filepattern::Regex)
    [file for file in readdir(dirpath, join=true) if occursin(filepattern, file)]
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

function getparseranges!(range_arr::Vector{UnitRange{Int32}}, line::AbstractString)
    length(range_arr) != 8 && throw(ArgumentError("range_arr must have length 8"))
    start = 1
    for i in 1:8
        r = findnext(" ", line, start)
        ending, next = prevind(line, first(r)), nextind(line,last(r))
        @inbounds range_arr[i] = start:ending
        start = next
    end
    return nothing
end

function parsehit(ranges::Vector{UnitRange{Int32}}, line::AbstractString)::MaGeHit
    getparseranges!(ranges, line)
    x =             parse(Float32, line[ranges[3]])
    y =             parse(Float32, line[ranges[1]])
    z =             parse(Float32, line[ranges[2]])
    E =             parse(Float32, line[ranges[4]])
    t =             parse(Float32, line[ranges[5]])
    particleid =    parse(Int32, line[ranges[6]])
    trackid =       parse(Int32, line[ranges[7]])
    trackparentid = parse(Int32, line[ranges[8]])

    # convert to detector coordinates [mm]
    xtal_length = 1
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length

    return MaGeHit(x, y, z, E, t, particleid, trackid, trackparentid)
end
parsehit(line::AbstractString) = parsehit(Vector{UnitRange{Int32}}(undef, 8), line)

function cleanhitfile(filepath::AbstractString)
    return filter(line -> length(line) > 30, readlines(filepath))
end

function parse_event(filepath::AbstractString)::MaGeEventVec
    return map(parsehit, cleanhitfile(filepath))
end

struct MaGeEvent
    filepath::AbstractString
end
each_hit(filepath::AbstractString) = MaGeEvent(filepath)

function iterate(iter::MaGeEvent, state)
    line_iter, range_arr = state
    next = iterate(line_iter)
    next === nothing && return nothing
    line, _ = next
    while length(line) < 30
        next = iterate(line_iter)
        next === nothing && return nothing
        line, _ = next
    end
    return parsehit(range_arr, line), (line_iter, range_arr)
end

function iterate(iter::MaGeEvent)
    return iterate(iter, (Vector{UnitRange{Int32}}(undef, 8), eachline(iter.filepath)))
end

calcenergy(event::MaGeEventVec) = sum(hit.E for hit in event)
calcenergy(event::MaGeEvent) = sum(hit.E for hit in event)
calcenergy(filepath::AbstractString) = calcenergy(MaGeEvent(filepath))
