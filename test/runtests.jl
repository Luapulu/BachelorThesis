using MaGeAnalysis, Test

const dir = joinpath(dirname(pathof(MaGeAnalysis)), "..", "test", "testfiles")
const testfilepath = joinpath(dir, "shortened.root.hits")

@test getmagepaths(dir, r"shortened.root.hits$") == [testfilepath]

@test MaGeAnalysis.parsehit("-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet") ==
      MaGeHit(-2.1, -3.7, 1.8, 0.3, 0, 22, 12, 9)

const testevent = iterate(iterate(getevents(testfilepath)))[1]
@test testevent == iterate(iterate(getevents(testfilepath, 595)))[1]

@test testevent[20] == MaGeHit(-200.813, -3.23994, 1.98329, 3.60329, 0.0, 11, 18, 12)

const mismatchedfilepath = joinpath(dir, "mismatchedhitcount.root.hits")
@test_throws ArgumentError iterate(getevents(mismatchedfilepath))

@test calcenergy(testevent) ≈ 846.77106

@test length(getevents(testfilepath)) == 3

@test map(calcenergy, getevents(testfilepath)) ≈ Float32[846.77106, 2598.5068, 1238.3121]

@test getcounts(calcenergy, getevents(testfilepath), 2, (847, 2000)) == [1, 1, 0, 1]

@test filemap([testfilepath]) do f; getcounts(calcenergy, f, 2, (840, 1240)); end == [[0, 1, 1, 1]]
