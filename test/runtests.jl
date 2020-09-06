using MaGeAnalysis, Test

dir = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "test", "testfiles"))
testfilepath = joinpath(dir, "shortened.root.hits")
badfilepath = joinpath(dir, "badfile.root.hits")
jldfilepath = joinpath(dir, "shortened.jld2")

file = eachevent(testfilepath)
testevent = (readevent(file); readevent(file))


@testset "Reading MaGe .root.hits files" begin

      @test magerootpaths(dir) == [badfilepath, testfilepath]

      @test MaGeAnalysis.parsehit("-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet") ==
            MaGeHit(-2.1, -3.7, 1.8, 0.3, 0, 22, 12, 9)

      for (i, event) in enumerate(eachevent(testfilepath))
            i == 2 && @test event == testevent
      end

      @test testevent[20] == MaGeHit(-196.341, 1.09405, -3.01024, 0.726026, 0.0, 11, 220, 9)

      badfilereader = eachevent(badfilepath)
      @test_throws ErrorException readevent(badfilereader) # hitcount too large
      @test_throws ErrorException readevent(badfilereader) # no meta line there
end


@testset "Writing and reading .jld2 files" begin

      savetojld([testfilepath], dir)
      @test first(magejldpaths(dir)) == jldfilepath
      jldf = eachevent(jldfilepath)

      @test Set(jldf) == Set(eachevent(testfilepath))
end


@testset "Analysing events" begin

      @test calcenergy(testevent) ≈ 2598.5068

      @test map(calcenergy, eachevent(testfilepath)) ≈
            Float32[846.77106, 2598.5068, 1238.3121]

      @test getcounts(calcenergy, eachevent(testfilepath), 2, (847, 2000)) == [1, 1, 0, 1]

      @test getcounts(calcenergy, eachevent(jldfilepath), 2, (847, 2000)) == [1, 1, 0, 1]

      @test filemap([testfilepath]) do f
            getcounts(calcenergy, eachevent(f), 2, (840, 1240))
      end == [[0, 1, 1, 1]]
end

rm(jldfilepath)
