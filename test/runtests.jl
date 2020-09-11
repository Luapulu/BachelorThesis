using Distributed, Test

if nprocs() < 2
      addprocs(1)
end

@everywhere using MaGeAnalysis, Statistics

dir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "test", "testfiles"))
delimpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.root.hits")
delimpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.root.hits")
badpath = joinpath(dir, "badfile.root.hits")
jldpath1 = joinpath(dir, "GWD6022_Co56_side50cm_1001.jld2")
jldpath2 = joinpath(dir, "GWD6022_Co56_side50cm_1871.jld2")

configpath = realpath("GWD6022_01ns.config")
setup = get_detector_setup(configpath)

testevents = MaGeEvent[e for e in eachevent(getfile(delimpath1, setup))]
delimtojld([delimpath1, delimpath2], dir, setup)

@testset "Reading MaGe .root.hits files" begin

      @test MaGeAnalysis.parsehit(
            "-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet",
            setup.xtal_length,
      ) == MaGeHit(1979.0, -37.0, 14.5, 0.3, 0.0, 22, 12, 9)

      @test Set(getdelimpaths(dir)) == Set([badpath, delimpath1, delimpath2])

      @test length(testevents) == 2934

      @test testevents[end].eventnum == 999851

      @test testevents[end].hitcount == 319

      @test testevents[end].primarycount == 4

      @test testevents[end][1] ==
            MaGeHit(31.860046, -12.325, 56.9103, 0.07764, 0.0, 22, 9, 6)

      @test testevents[end][end] ==
            MaGeHit(10.420074, -11.8914995, 55.3214, 8.4419, 0.0, 11, 165, 16)

      badfile = getfile(badpath, setup)
      @test_throws ErrorException readevent(badfile) # hitcount too large
      @test_throws ErrorException readevent(badfile) # no meta line there
end


@testset "Writing and reading .jld2 files" begin

      @test eachevent(getfile(jldpath1)) == testevents

      @test eachevent(getfile(jldpath2))[1] == iterate(getfile(delimpath2, setup))[1]
end


@testset "Analysing events" begin

      @test calcenergy(testevents[1]) ≈ 510.9989

      @test filemap([jldpath1, jldpath2]) do f
            mean(calcenergy, eachevent(f))
      end ≈ Float32[854.326, 838.74255]
end

rm(jldpath1)
rm(jldpath2)
