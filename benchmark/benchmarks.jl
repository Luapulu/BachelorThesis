using BenchmarkTools, Profile, Random

# dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "test"))
# jldpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld2")
# jldpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.jld2")
#
# configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
# init_detector(configpath)
#
# get_signals(e -> e.fileindex <= 1, [jldpath1, jldpath2], joinpath(dir, "signals"))
#
# Profile.clear()
#
# @profile @time get_signals(e -> e.fileindex <= 5, [jldpath1, jldpath2], joinpath(dir, "signals"))
#
# Profile.print(mincount=100)

const HitTuple = NamedTuple{
    (:x, :y, :z, :E, :t, :particleid, :trackid, :trackparentid),
    Tuple{Float32,Float32,Float32,Float32,Float32,Int32,Int32,Int32},
}

ishitline(line::AbstractString) = length(line) > 20 && line[end-8:end] == " physiDet"

function get_parse_ranges!(ranges::Vector{UnitRange{T}}, line::AbstractString) where {T<:Integer}
    start = 1
    for i = 1:8
        r = findnext(" ", line, start)
        ending, next = prevind(line, first(r)), nextind(line, last(r))
        ranges[i] = start:ending
        start = next
    end
    return ranges
end

function parse_hit!(ranges::Vector{UnitRange{T}}, line::AbstractString) where {T<:Integer}
    !ishitline(line) && error("cannot parse \"$line\" as hit")
    ranges = get_parse_ranges!(ranges, line)
    x = parse(Float32, line[ranges[3]])
    y = parse(Float32, line[ranges[1]])
    z = parse(Float32, line[ranges[2]])
    E = parse(Float32, line[ranges[4]])
    t = parse(Float32, line[ranges[5]])
    particleid = parse(Int32, line[ranges[6]])
    trackid = parse(Int32, line[ranges[7]])
    trackparentid = parse(Int32, line[ranges[8]])

    return HitTuple((x, y, z, E, t, particleid, trackid, trackparentid))
end

function parse_hit2!(stream::IO)
    y = parse(Float32, readuntil(stream, ' '))
    z = parse(Float32, readuntil(stream, ' '))
    x = parse(Float32, readuntil(stream, ' '))
    E = parse(Float32, readuntil(stream, ' '))
    t = parse(Float32, readuntil(stream, ' '))
    particleid = parse(Int32, readuntil(stream, ' '))
    trackid = parse(Int32, readuntil(stream, ' '))
    trackparentid = parse(Int32, readuntil(stream, ' '))

    skip(stream, 9)

    return HitTuple((x, y, z, E, t, particleid, trackid, trackparentid))
end

ranges = Vector{UnitRange{Int32}}(undef, 8)

str = "1.60738 -2.07026 -201.594 0.1638 0 22 187 4 physiDet\n1.91771 -2.52883 -201.842 0.24458 0 22 187 4 physiDet"

function func1(ranges, str)
    io = IOBuffer(str)
    parse_hit!(ranges, readline(io))
    parse_hit!(ranges, readline(io))
    nothing
end

function func2(ranges, str)
    io = IOBuffer(str)
    parse_hit2!(io)
    parse_hit2!(io)
    nothing
end

b1 = @benchmark func1($ranges, $str)
b2 = @benchmark func2($ranges, $str)

display(b1)
display(b2)
