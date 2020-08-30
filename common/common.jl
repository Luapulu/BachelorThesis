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

function geteventfiles(dirpath::AbstractString, filepattern::Regex)
    [file for file in readdir(dirpath, join=true) if occursin(filepattern, file)]
end

function parsehit(line::String, xtal_length=1)::MaGeHit
    linearr = split(line, " ")
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

function cleanhitfile(filepath::AbstractString)::Vector{String}
    return [line for line in eachline(filepath) if length(split(line, " ")) == 9]
end

function parseevent(filepath::AbstractString)::Vector{MaGeHit}
    return map(parsehit, cleanhitfile(filepath))
end

function parseevent2(filepath::AbstractString)::Vector{MaGeHit}
    return [parsehit(line) for line in eachline(filepath) if length(split(line, " ")) == 9]
end
