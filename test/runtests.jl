using Test, MaGeSigGen, MJDSigGen, Statistics

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "test"))

configpath = joinpath(dir, "GWD6022_01ns.config")
init_detector(configpath)

eventpath = joinpath(dir, "events", "GWD6022_Co56_side50cm_1001.root.hits")
badpath = joinpath(dir, "badfile.root.hits")

all_events = MaGeEvent[e for e in eachevent(eventpath)]
testevent = all_events[1]

@testset "Loading events from .root.hits files" begin

    @test MaGeSigGen.parsehit(
        "-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet",
        MaGeSigGen.SETUP.xtal_length,
    ) == MaGeHit(1979.0, -37.0, 14.5, 0.3, 0.0, 22, 12, 9)

    @test length(all_events) == 2934

    @test all(e.fileindex == i for (i, e) in enumerate(all_events))

    @test all_events[end].eventnum == 999851

    @test all_events[end].hitcount == 319

    @test all_events[end].primarycount == 4

    @test all_events[end][1] == MaGeHit(31.860046, -12.325, 56.9103, 0.07764, 0.0, 22, 9, 6)

    @test all_events[end][end] == MaGeHit(10.420074, -11.8914995, 55.3214, 8.4419, 0.0, 11, 165, 16)

    badfile = MaGeSigGen.EventFile(badpath)
    @test_throws ErrorException MaGeSigGen.readevent(badfile, 1) # hitcount too large
    @test_throws ErrorException MaGeSigGen.readevent(badfile, 2) # no meta line there
end

@testset "Saving and loading events to/from .jld files" begin

    eventpathjld = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld")
    isfile(eventpathjld) && rm(eventpathjld)

    save(eventpathjld, all_events)

    @test get_events(eventpathjld) == all_events

    isfile(eventpathjld) && rm(eventpathjld)

    events_to_jld(eventpath, dir)

    @test get_events(eventpathjld) == all_events
end


@testset "Event processing" begin

    @test energy(testevent) == 510.9989f0
end

testsignal = get_signal(testevent)
signalvec = get_signals(all_events[2:3], length(all_events))

@testset "Signal generation" begin

    h = all_events[1][1]
    @test get_signal(h) ≈ MJDSigGen.get_signal!(MaGeSigGen.SETUP, (h.x, h.y, h.z))

    @test 0 <= testsignal[1] < 0.05 * energy(testevent)

    @test testsignal[end] ≈ energy(testevent)

    @test ismissing(signalvec[1])

    n = length(all_events)
    @test_logs (:info, "Worker 1 got 3 of $n events and generated 1 signals") get_signals!(
        signalvec,
        all_events[1:3],
    )

    @test signalvec[1] ≈ testsignal

    new_event = MaGeEvent(all_events[3][1:5], 4, 5, 2, 1)

    get_signals!(signalvec, [new_event], replace = false)

    @test signalvec[1] ≈ testsignal

    get_signals!(signalvec, [new_event], replace = true)

    @test !(signalvec[1] ≈ testsignal)
end

@testset "Saving and loading signals to/from .jld files" begin
    signalpath = joinpath(dir, "testsignals.jld")
    isfile(signalpath) && rm(signalpath)

    save(signalpath, signalvec)

    @test isequal(get_signals(signalpath), signalvec)
end

@testset "Signal processing" begin
    @test getA(testsignal) == maximum(diff(testsignal))

    @test energy(testsignal) ≈ energy(testevent)
end
