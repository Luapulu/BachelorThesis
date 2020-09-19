using Test, MaGeSigGen, MJDSigGen, Statistics

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "test"))

configpath = joinpath(dir, "GWD6022_01ns.config")

eventpath = joinpath(dir, "events", "GWD6022_Co56_side50cm_1001.root.hits")
badpath = joinpath(dir, "badfile.root.hits")


@testset "Detector" begin

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

    @test location(h) == (1.1, 2.2, 3.3)
    @test energy(h) == 4.4
    @test time(h) == 5.5
    @test particleid(h) == 6
    @test trackid(h) == 7
    @test trackparentid(h) == 8

    nt = (x=1.1, y=2.2, z=3.3, E=4.4, t=5.5, particleid=6, trackid=7, trackparentid=8)
    @test Hit(nt) == h
    @test convert(Hit, nt) == h

    @test_throws InexactError Hit(1, 2, 3, 4, 5, 1.1, 2.2, 3.3)
end

@testset "Events" begin
    v = [Hit(i*i, sqrt(i), 3.5, 4, 1000.5, 1, 2, 3) for i in 1:5]
    e = MaGeSigGen.Event(1, 5, 2, v)

end


# @testset "Loading events from .root.hits files" begin
#
#     @test MaGeSigGen.parse_hit(
#         IOBuffer("-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet"),
#         MaGeSigGen.SETUP.xtal_length,
#     ) == Hit(1979.0, -37.0, 14.5, 0.3, 0.0, 22, 12, 9)
#
#     @test length(all_events) == 2934
#
#     @test all(e.fileindex == i for (i, e) in enumerate(all_events))
#
#     @test all_events[end].eventnum == 999851
#
#     @test all_events[end].hitcount == 319
#
#     @test all_events[end].primarycount == 4
#
#     @test all_events[end][1] == Hit(31.860046, -12.325, 56.9103, 0.07764, 0.0, 22, 9, 6)
#
#     @test all_events[end][end] == Hit(10.420074, -11.8914995, 55.3214, 8.4419, 0.0, 11, 165, 16)
#
#     badfile = MaGeSigGen.RootHitEvents(badpath)
#     @test_throws ErrorException MaGeSigGen.parse_event(badfile, 1) # hitcount too large
#     @test_throws ErrorException MaGeSigGen.parse_event(badfile, 2) # no meta line there
# end
#
# @testset "Saving and loading events to/from .jld files" begin
#
#     eventpathjld = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld")
#     isfile(eventpathjld) && rm(eventpathjld)
#
#     save(eventpathjld, all_events)
#
#     @test get_events(eventpathjld) == all_events
#
#     isfile(eventpathjld) && rm(eventpathjld)
#
#     events_to_jld(eventpath, dir)
#
#     @test get_events(eventpathjld) == all_events
# end
#
#
# @testset "Event processing" begin
#
#     @test energy(testevent) == 510.9989f0
# end
#
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
