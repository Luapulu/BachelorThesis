using Test, MaGeSigGen, MJDSigGen, MaGe, Statistics, DSP

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "test"))
setup_path = joinpath(dir, "GWD6022_01ns.config")

const setup = MJDSigGen.signal_calc_init(setup_path)

@testset "Detector Setup" begin

    out = with_group_effects!(setup, 5.7, 3.1, "some other argument") do stp, arg
        return (
            stp.energy,
            stp.charge_cloud_size,
            stp.use_diffusion,
            stp.use_acceleration,
            stp.use_repulsion,
            arg
        )
    end

    @test all(out .== (5.7f0, 3.1f0, 1, 1, 1, "some other argument"))

    @test setup.charge_cloud_size == 0
    @test setup.energy == 0
    @test setup.use_diffusion == 0
    @test setup.use_acceleration == 0
    @test setup.use_repulsion == 0

    x, y, z = (1.0, 2.0, 3.0)
    @test todetcoords(x, y, z, setup.xtal_length) == (
        (z + 200) * 10, x * 10, -10 * y + setup.xtal_length / 2
    )

    h = Hit(1, 2, 3, 4, 5, 6, 7, 8)
    @test todetcoords(h, setup) == Hit(
        (3 + 200) * 10, 1 * 10, -10 * 2 + setup.xtal_length / 2,
        4, 5, 6, 7, 8
    )
end


@testset "Signals" begin
    @testset "Signal generation" begin

        eventpath = joinpath(dir, "events", "GWD6022_Co56_side50cm_1001.root.hits")
        testevent, event2, event3 = MaGe.loadstreaming(eventpath) do stream
            e1 = todetcoords!(read(stream), setup)
            e2 = todetcoords!(read(stream), setup)
            e3 = todetcoords!(read(stream), setup)
            return e1, e2, e3
        end

        testsignal = get_signal(setup, testevent)

        @test length(testsignal) == setup.ntsteps_out == 4000

        @test all(0 .<= testsignal .< energy(testevent) * (1 + 1e-6))

        @test all(0 .<= diff(testsignal))

        @test 0 <= testsignal[1] < 0.05 * energy(testevent)

        @test testsignal[end] ≈ energy(testevent)  # only if all hits in detector

        sgnls = get_signals(SignalDict, setup, [testevent, event3])

        @test sgnls[testevent] ≈ testsignal

        @test ismissing(sgnls[event2])

        @test_logs (:info, "Worker 1 got 2 events and generated 1 signals") get_signals!(
            sgnls,
            setup,
            [event2, testevent]
        )

        get_signals!(sgnls, setup, [event2, testevent])

        @test sgnls[event2] ≈ get_signal(setup, event2)

        @test count(e->true, signals(sgnls)) == 3
        @test eltype(typeof(sgnls)) == Vector{Float32}

        new_testevent = Event(eventnum(testevent), 2, primarycount(testevent), hits(testevent)[1:2])

        get_signals!(sgnls, setup, [new_testevent])

        @test sgnls[new_testevent] ≈ testsignal

        get_signals!(sgnls, setup, [new_testevent], replace = true)

        @test sgnls[new_testevent] ≈ get_signal(setup, new_testevent)
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
        time_step = 5

        @test getA(s) == maximum(diff(s)) ≈ 0.8

        @test drift_time(s, 0.6f0, 1.8f0, time_step) == 2 * time_step

        @test drift_time(s, -Inf, Inf, time_step) == length(s) * time_step
        @test drift_time(s, time_step) == length(s) * time_step

        @test charge_cloud_size(0.005) == 0.01

        @test charge_cloud_size(1234.5) ≈ 0.37973124300111993

        σ = time_step / (2 * √(2 * log(2)))
        win = [exp(-0.5 * (x / σ)^2) for x in LinRange(-4σ, 4σ, round(Int, 8 * σ / time_step))]
        @test all(MaGeSigGen.gausswindow(σ, 4, time_step) .≈ win)

        l = (10, 10, 10)
        @test with_group_effects!(setup, 1234.5, charge_cloud_size(1234.5), l) do stp, loc
            getδτ(stp, loc)
        end == 26.61690290683232610

        gs = apply_group_effects(s, time_step, time_step, true)
        gs ./= gs[end]

        pad_s = [s; 2.0; 2.0]
        expected = conv(pad_s, win)[1:end-2]
        expected ./= expected[end]

        @test all(-1e-10 .< gs .< (1 + 1e-10))
        @test all(-1e-10 .< diff(gs))
        @test gs ≈ expected
        @test length(gs) == 8 + 3 - 1

        E = 1234.5
        σE = 67.8
        s2 = copy(s)
        Es = [set_noisy_energy!(s2, E, σE)[end] for _ in 1:1000]

        @test E - σE < mean(Es) < E + σE
        @test 0.9 * σE < std(Es) < 1.1 * σE

        smooth1 = MaGeSigGen.moving_average(s, 4)
        @test isapprox(smooth1, [0.55, 0.55, 1.0, 1.45, 1.8, 1.95, 1.95, 1.95], rtol=1e-6)

        smooth2 = MaGeSigGen.moving_average(s, 2)
        smooth2 = MaGeSigGen.moving_average(smooth2, 2)
        smooth2 = MaGeSigGen.moving_average(smooth2, 2)
        @test isapprox(MaGeSigGen.moving_average(s, 2, 3), smooth2, rtol=1e-6)

        s3 = copy(s)
        noisy_signal = Float32[
            0.0f0 - 0.1, 0.2f0 + 0.2, 0.6f0 - 0.2,
            1.4f0 + 0.1, 1.8f0 - 0.1, 2.0f0 + 0.2,
            2.0f0 - 0.2, 2.0f0 + 0.1]
        @test addnoise!(s3, [0.1, -0.1, 0.2, -0.2], 2) == noisy_signal
    end
end
