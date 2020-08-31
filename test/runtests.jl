using MaGe, Test

const dir = joinpath(dirname(pathof(MaGe)), "..", "test", "testfiles")
const testfilepath = joinpath(dir, "shortened.root.hits")

@test geteventfiles(dir, r"shortened.root.hits$") == [testfilepath]

@test MaGe.parsehit("-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet") ==
      MaGeHit(-2.1, -3.7, 1.8, 0.3, 0, 22, 12, 9)

const testevent = iterate(iterate(eachevent(testfilepath)))[1]
@test testevent == iterate(iterate(eachevent(testfilepath, 595)))[1]

@test testevent[20] == MaGeHit(-200.813, -3.23994, 1.98329, 3.60329, 0.0, 11, 18, 12)

const mismatchedfilepath = joinpath(dir, "mismatchedhitcount.root.hits")
@test_throws ArgumentError iterate(eachevent(mismatchedfilepath))

@test calcenergy(testevent) ≈ 846.77106

@test length(eachevent(testfilepath)) == 3

@test map(calcenergy, eachevent(testfilepath)) ≈ Float32[846.77106, 2598.5068, 1238.3121]

@test calcfrequencies(calcenergy, eachevent(testfilepath), 2, (800, 2000)) == [2, 1]
