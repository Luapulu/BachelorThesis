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

testevents = MaGeEvent[e for e in eachevent(getfile(delimpath1))]
delimtojld([delimpath1, delimpath2], dir)

@testset "Reading MaGe .root.hits files" begin

      @test MaGeAnalysis.parsehit("-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet") ==
            MaGeHit(-2.1, -3.7, 1.8, 0.3, 0, 22, 12, 9)

      @test Set(getdelimpaths(dir)) == Set([badpath, delimpath1, delimpath2])

      @test length(testevents) == 2934

      @test testevents[end].eventnum == 999851

      @test testevents[end].hitcount == 319

      @test testevents[end].primarycount == 4

      @test testevents[end][1] == MaGeHit(-196.814, -1.2325, -2.44103, 0.07764, 0, 22, 9, 6)

      @test testevents[end][end] == MaGeHit(-198.958, -1.18915, -2.28214, 8.4419, 0, 11, 165, 16)

      badfile = getfile(badpath)
      @test_throws ErrorException readevent(badfile) # hitcount too large
      @test_throws ErrorException readevent(badfile) # no meta line there
end


@testset "Writing and reading .jld2 files" begin

      @test eachevent(getfile(jldpath1)) == testevents

      @test eachevent(getfile(jldpath2))[1] == iterate(eachevent(getfile(delimpath2)))[1]
end


@testset "Analysing events" begin

      @test calcenergy(testevents[1]) ≈ 510.9989

      @test filemap([jldpath1, jldpath2]) do f
            mean(calcenergy, eachevent(f))
      end ≈ Float32[854.326, 838.74255]
end

rm(jldpath1)
rm(jldpath2)
