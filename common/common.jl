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

function parsehit(linearr::Vector{SubString{String}}, xtal_length=1)::MaGeHit
    x =             parse(Float32, linearr[3])
    y =             parse(Float32, linearr[1])
    z =             parse(Float32, linearr[2])
    E =             parse(Float32, linearr[4])
    t =             parse(Float32, linearr[5])
    particleid =    parse(Int32, linearr[6])
    trackid =       parse(Int32, linearr[7])
    trackparentid = parse(Int32, linearr[8])

    # convert to detector coordinates [mm]
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length

    return MaGeHit(x, y, z, E, t, particleid, trackid, trackparentid)
end

function cleanhitfile(filepath::AbstractString)
    splitlines = map(line -> split(line, " "), readlines(filepath))
    return filter(linearr -> length(linearr) == 9, splitlines)
end

function parse_event(filepath::AbstractString)::MaGeEventVec
    return map(parsehit, cleanhitfile(filepath))
end

struct MaGeEvent
    filepath::AbstractString
end
each_hit(filepath::AbstractString) = MaGeEvent(filepath)

function iterate(iter::MaGeEvent, line_iter=eachline(iter.filepath))
    splitline = SubString{String}[]
    while length(splitline) != 9
        next = iterate(line_iter)
        line, _ = next !== nothing ? next : return nothing
        splitline = split(line, " ")
    end
    hit = parsehit(splitline)
    return hit, line_iter
end

calcenergy(event::MaGeEventVec) = sum(hit.E for hit in event)
calcenergy(event::MaGeEvent) = sum(hit.E for hit in event)
