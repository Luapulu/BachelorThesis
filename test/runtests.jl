using Test, MaGeSigGen, MJDSigGen, Statistics

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "test"))


@testset "Detector" begin
    configpath = joinpath(dir, "GWD6022_01ns.config")
    @test_logs (:info, "Initialised detector setup with $configpath") init_detector(configpath)

    @test_throws ErrorException init_detector(configpath)

    @test isa(MaGeSigGen.SETUP, MJDSigGen.Struct_MJD_Siggen_Setup)

    @test outside_detector((10, 10, 10)) == false
    @test outside_detector((-10, 0, -10)) == true

    x, y, z = (1.0, 2.0, 3.0)
    @test MaGeSigGen.to_detector_coords(x, y, z) == ((z + 200) * 10, x * 10, -10 * y + 65 / 2)
end


@testset "Hits" begin
    h = Hit(1.1, 2.2, 3.3, 4.4, 5.5, 6, 7, 8)

    @test location(h) == (1.1f0, 2.2f0, 3.3f0)
    @test energy(h) == 4.4f0
    @test time(h) == 5.5f0
    @test particleid(h) == 6
    @test trackid(h) == 7
    @test trackparentid(h) == 8

    nt = (x=1.1, y=2.2, z=3.3, E=4.4, t=5.5, particleid=6, trackid=7, trackparentid=8)
    @test Hit(nt) == h
    @test convert(Hit, nt) == h

    @test_throws InexactError Hit(1, 2, 3, 4, 5, 1.1, 2.2, 3.3)
end


@testset "Events" begin
    v = [Hit(i*i, sqrt(i), 3.5, 4, 0.5, 1, 2, 3) for i in 1:5]
    e = Event(1, 5, 2, v)

    @test eltype(typeof(e)) == Hit

    @test energy(e) == 4*5

    @test hits(e) == v
    @test eventnum(e) == 1
    @test length(e) == hitcount(e) == 5
    @test primarycount(e) == 2

    @test_throws ArgumentError Event(1, 3, 2, v)
end


@testset "Parsing .root.hits files" begin
    meta_stream = IOBuffer("""624 119 3\n""")
    @test MaGeSigGen.parse_meta(meta_stream) == (624, 119, 3)

    hit_stream = IOBuffer(
        """
        1.60738 -2.07026 -201.594 0.1638 0 22 187 4 physiDet
        1.91771 -2.52883 -201.842 0.24458 0 22 187 4 physiDet
        """)

    parsed1 = MaGeSigGen.parse_hit(hit_stream)
    known1 = (-15.94, 16.0738, 53.2026, 0.1638, 0, 22, 187, 4)
    @test all(parsed1 .≈ known1)

    parsed2 = MaGeSigGen.parse_hit(hit_stream)
    x, y, z = MaGeSigGen.to_detector_coords(1.91771, -2.52883, -201.842)
    known2 = (x, y, z, 0.24458, 0, 22, 187, 4)
    @test all(parsed2 .≈ known2)

    test_stream = IOBuffer(
        """
        624 2 3
        1.60738 -2.07026 -201.594 0.1638 0 22 187 4 physiDet
        1.91771 -2.52883 -201.842 0.24458 0 22 187 4 physiDet
        """)

    test_reader = MaGeSigGen.RootHitReader(test_stream)

    result, _ = iterate(test_reader)
    enum, hitcnt, primcnt, hit_itr = result
    @test enum == 624
    @test hitcnt == 2
    @test primcnt == 3

    parsed_hits = [
        MaGeSigGen.parse_hit(IOBuffer("1.60738 -2.07026 -201.594 0.1638 0 22 187 4 physiDet")),
        MaGeSigGen.parse_hit(IOBuffer("1.91771 -2.52883 -201.842 0.24458 0 22 187 4 physiDet"))
    ]
    for (i, hit) in enumerate(hit_itr)
        @test all(hit .== parsed_hits[i])
    end

    @test isnothing(iterate(test_reader))

    eventpath = joinpath(dir, "events", "GWD6022_Co56_side50cm_1001.root.hits")

    @test MaGeSigGen.is_root_hit_file(eventpath)

    filereader = MaGeSigGen.RootHitReader(eventpath)
    for e in Base.Iterators.take(filereader, 2933)
        Event{Vector{Hit}}(e)
    end

    last, _ = iterate(filereader)

    lastevent = Event{Vector{Hit}}(last)

    @test eventnum(lastevent) == 999851

    @test hitcount(lastevent) == 319

    @test primarycount(lastevent) == 4

    @test lastevent[1] == Hit(31.86, -12.325, 56.9103, 0.07764, 0.0, 22, 9, 6)

    @test lastevent[end] == Hit(10.42, -11.8915, 55.3214, 8.4419, 0.0, 11, 165, 16)

    @test isnothing(iterate(filereader))

    badpath = joinpath(dir, "badfile.root.hits")
    badreader = MaGeSigGen.RootHitReader(badpath)
    e, _ = iterate(badreader)
    @test_throws ArgumentError Event{Vector{Hit}}(e)
    @test_throws ArgumentError iterate(badreader)
end


# testsignal = get_signal(testevent)
# signalvec = get_signals(all_events[2:3], length(all_events))
#
# @testset "Signal generation" begin
#
#     h = all_events[1][1]
#     @test get_signal(h) ≈ MJDSigGen.get_signal!(MaGeSigGen.SETUP, (h.x, h.y, h.z))
#
#     @test 0 <= testsignal[1] < 0.05 * energy(testevent)
#
#     @test testsignal[end] ≈ energy(testevent)
#
#     @test ismissing(signalvec[1])
#
#     n = length(all_events)
#     @test_logs (:info, "Worker 1 got 3 of $n events and generated 1 signals") get_signals!(
#         signalvec,
#         all_events[1:3],
#     )
#
#     @test signalvec[1] ≈ testsignal
#
#     new_event = Event(all_events[3][1:5], 4, 5, 2, 1)
#
#     get_signals!(signalvec, [new_event], replace = false)
#
#     @test signalvec[1] ≈ testsignal
#
#     get_signals!(signalvec, [new_event], replace = true)
#
#     @test !(signalvec[1] ≈ testsignal)
# end
#
# @testset "Saving and loading signals to/from .jld files" begin
#     signalpath = joinpath(dir, "testsignals.jld")
#     isfile(signalpath) && rm(signalpath)
#
#     save(signalpath, signalvec)
#
#     @test isequal(get_signals(signalpath), signalvec)
# end
#
# @testset "Signal processing" begin
#     @test getA(testsignal) == maximum(diff(testsignal))
#
#     @test energy(testsignal) ≈ energy(testevent)
# end
