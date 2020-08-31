using MaGe, Test

const dir = joinpath(dirname(pathof(MaGe)), "..", "test", "testfiles")
const testfilepath = joinpath(dir, "shortened.root.hits")

@test geteventfiles(dir, r".root.hits$") == [testfilepath]

@test MaGe.parsehit("-3.7 1.8 -2.1 0.3 0 22 12 9 physiDet") ==
      MaGeHit(-2.1, -3.7, 1.8, 0.3, 0, 22, 12, 9)

for event in eachevent(testfilepath)
      println(event)
end
