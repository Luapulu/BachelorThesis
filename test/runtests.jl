using Distributed, Test, MJDSigGen, Logging

nprocs() < 3 && addprocs(3 - nprocs())

@everywhere using MaGeAnalysis, Statistics

eventdir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "test", "events"))
dir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "test"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_setup($configpath)

delimpath1 = joinpath(eventdir, "GWD6022_Co56_side50cm_1001.root.hits")
delimpath2 = joinpath(eventdir, "GWD6022_Co56_side50cm_1871.root.hits")
badpath = joinpath(dir, "badfile.root.hits")

testevents = MaGeEvent[e for e in eachevent(delimpath1)]

@testset "Loading events from .root.hits files" begin

    @test MaGeAnalysis.parsehit(
        "-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet",
        MaGeAnalysis.SETUP.xtal_length,
    ) == MaGeHit(1979.0, -37.0, 14.5, 0.3, 0.0, 22, 12, 9)

    @test length(testevents) == 2934

    @test all(e.fileindex == i for (i, e) in enumerate(testevents))

    @test testevents[end].eventnum == 999851

    @test testevents[end].hitcount == 319

    @test testevents[end].primarycount == 4

    @test testevents[end][1] == MaGeHit(31.860046, -12.325, 56.9103, 0.07764, 0.0, 22, 9, 6)

    @test testevents[end][end] == MaGeHit(10.420074, -11.8914995, 55.3214, 8.4419, 0.0, 11, 165, 16)

    badfile = MaGeAnalysis.DelimFile(badpath)
    @test_throws ErrorException MaGeAnalysis.readevent(badfile, 1) # hitcount too large
    @test_throws ErrorException MaGeAnalysis.readevent(badfile, 2) # no meta line there
end

jldpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld2")
jldpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.jld2")
isfile(jldpath1) && rm(jldpath1)
isfile(jldpath2) && rm(jldpath2)

@testset "Saving and loading events from/to .jld2 files" begin

    eventstojld(eventdir, dir)

    @test get_events(jldpath1) == testevents

    @test get_events(jldpath2)[1] == iterate(eachevent(delimpath2))[1]
end


@testset "Analysing events" begin

    @test energy(testevents[1]) ≈ 510.9989

    @test filemap([jldpath1, jldpath2]) do f
        mean(energy, get_events(f))
    end ≈ Float32[854.326, 838.74255]
end

@testset "Signals" begin

    testsignal = get_signal(testevents[1])

    @testset "Generating signals for events and hits" begin

        h = testevents[1][1]
        @test get_signal(h) ≈ MJDSigGen.get_signal!(MaGeAnalysis.SETUP, (h.x, h.y, h.z))

        @test 0 < testsignal[1] < 0.05 * energy(testevents[1])

        @test testsignal[end] ≈ energy(testevents[1])
    end

    sigs = get_signals(testevents[2:5], length(testevents))

    @testset "Generating signals for multiple events" begin

        @test ismissing(sigs[1])

        get_signals!(sigs, testevents[1:3])

        @test sigs[1] ≈ testsignal

        new_event = MaGeEvent(testevents[3][1:5], 4, 5, 2, 1)

        get_signals!(sigs, [new_event], replace = false)

        @test sigs[1] ≈ testsignal

        get_signals!(sigs, [new_event], replace = true)

        @test !(sigs[1] ≈ testsignal)

        # Reset sigs[1] to testsignal
        sigs[1] = testsignal
    end

    signalpath = joinpath(dir, "testsignals.jld2")
    isfile(signalpath) && rm(signalpath)

    @testset "Saving and loaing signals" begin

        save_signals(sigs, signalpath)

        loaded_sigs = get_signals(signalpath)

        @test all(loaded_sigs[i] == sigs[i] for i = 1:5)

        @test all(ismissing(e) for e in loaded_sigs[6:end])
    end

    @testset "Getting signals for multiple files" begin
        signalpath1 = joinpath(dir, "signals", "GWD6022_Co56_side50cm_1001_signals.jld2")
        signalpath2 = joinpath(dir, "signals", "GWD6022_Co56_side50cm_1871_signals.jld2")
        isfile(signalpath1) && rm(signalpath1)
        isfile(signalpath2) && rm(signalpath2)

        get_signals(e -> e.fileindex == 1, [jldpath1, jldpath2], joinpath(dir, "signals"))

        @test get_signals(signalpath1)[1] ≈ testsignal

        @test all(ismissing(s) for s in get_signals(signalpath1)[2:end])

        is_second_event(e::MaGeEvent) = e.fileindex == 2
        get_signals!(is_second_event, [jldpath1, jldpath2], joinpath(dir, "signals"))

        @test !ismissing(get_signals(signalpath2)[2])

        @test all(ismissing(s) for s in get_signals(signalpath2)[3:end])
    end
end
