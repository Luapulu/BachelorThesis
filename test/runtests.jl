using Test, MaGeSigGen, MJDSigGen, Statistics, Parsers

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


@testset "Hits and Events" begin
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
        meta_stream = IOBuffer("624 119 3\n")
        @test MaGeSigGen.parse_meta(meta_stream) == (624, 119, 3)

        hit_stream = IOBuffer(
            """
            1.60738 -2.07026 -201.594 0.1638 0 22 187 4 physiDet
            1.91771 -2.52883 -201.842 0.24458 0 22 187 4 physiDet
            """)

        @test all(MaGeSigGen.parse_hit(hit_stream) .≈ (-15.94, 16.0738, 53.2026, 0.1638, 0, 22, 187, 4))

        x, y, z = MaGeSigGen.to_detector_coords(1.91771, -2.52883, -201.842)
        expected = (x, y, z, 0.24458, 0, 22, 187, 4)
        @test all(MaGeSigGen.parse_hit(hit_stream) .≈ expected)

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

        @test isa(MaGeSigGen.event_reader(eventpath), MaGeSigGen.RootHitReader)

        loader = load_events(Event{Vector{Hit}}, eventpath)
        for e in Base.Iterators.take(loader, 2933); "skipping all but last event"; end

        lastevent, _ = iterate(loader)

        @test eventnum(lastevent) == 999851

        @test hitcount(lastevent) == 319

        @test primarycount(lastevent) == 4

        @test lastevent[1] == Hit(31.86, -12.325, 56.9103, 0.07764, 0.0, 22, 9, 6)

        @test lastevent[end] == Hit(10.42, -11.8915, 55.3214, 8.4419, 0.0, 11, 165, 16)

        @test isnothing(iterate(loader))

        badpath = joinpath(dir, "badfile.root.hits")
        badreader = MaGeSigGen.RootHitReader(badpath)
        e, _ = iterate(badreader)
        @test_throws Parsers.Error Event{Vector{Hit}}(e)
        @test_throws Parsers.Error iterate(badreader)
    end
end

@testset "Signals" begin
    @testset "Signal generation" begin
        pulse = Vector{Float32}(undef, MaGeSigGen.SETUP.ntsteps_out)
        get_signal!(pulse, (10, 10, 10))

        @test pulse ≈ MJDSigGen.get_signal!(MaGeSigGen.SETUP, (10, 10, 10))

        @test get_signal((10, 10, 10)) ≈ MJDSigGen.get_signal!(MaGeSigGen.SETUP, (10, 10, 10))

        eventpath = joinpath(dir, "events", "GWD6022_Co56_side50cm_1001.root.hits")
        loader = load_events(Event{Vector{Hit}}, eventpath)
        testevent, _ = iterate(loader)
        event2, _ = iterate(loader)
        event3, _ = iterate(loader)

        testsignal = get_signal(testevent)

        @test length(testsignal) == MaGeSigGen.SETUP.ntsteps_out == 4000

        @test all(0 .<= testsignal .< energy(testevent) * (1 + 1e-6))

        @test all(0 .<= diff(testsignal))

        @test 0 <= testsignal[1] < 0.05 * energy(testevent)

        @test testsignal[end] ≈ energy(testevent)  # only if all hits in detector

        sgnls = get_signals(SignalDict, [testevent, event3])

        @test sgnls[testevent] ≈ testsignal

        @test ismissing(sgnls[event2])

        @test_logs (:info, "Worker 1 got 2 events and generated 1 signals") get_signals!(
            sgnls,
            [event2, testevent]
        )

        get_signals!(sgnls, [event2, testevent])

        @test sgnls[event2] ≈ get_signal(event2)

        @test count(e->true, signals(sgnls)) == 3
        @test eltype(typeof(sgnls)) == Vector{Float32}

        new_testevent = Event(eventnum(testevent), 2, primarycount(testevent), hits(testevent)[1:2])

        get_signals!(sgnls, [new_testevent])

        @test sgnls[new_testevent] ≈ testsignal

        get_signals!(sgnls, [new_testevent], replace = true)

        @test sgnls[new_testevent] ≈ get_signal(new_testevent)
    end


    @testset "Saving and loading signals to/from .jld files" begin
        sgnls = SignalDict(Dict(5=>fill(3.0, 4000), 2=>(fill(77.3, 4000))))

        signalpath = joinpath(dir, "testsignals.jld")
        isfile(signalpath) && rm(signalpath)

        save(signalpath, sgnls)

        loaded = load_signals(SignalDict, signalpath)
        @test all(loaded[k] == sgnls[k] for k in keys(sgnls))
    end


    @testset "Signal processing" begin
        s = Float32[0.0, 0.2, 0.6, 1.4, 1.8, 2.0, 2.0, 2.0]

        @test getA(s) == maximum(diff(s)) ≈ 0.8

        @test total_drift_time(s, 5) == 30
    end
end
