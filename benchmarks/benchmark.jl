using MaGeAnalysis, Profile, BenchmarkTools

dir = joinpath(dirname(pathof(MaGeAnalysis)), "..", "test", "testfiles")
testfilepath = joinpath(dir, "shortened.root.hits")
jldfilepath = joinpath(dir, "jldtest.jld2")

savetojld(testfilepath, jldfilepath)
jldf = eachevent(jldfilepath)

@btime getcounts(calcenergy, eachevent(testfilepath), 2, (847, 2000))
@btime getcounts(calcenergy, eachevent(jldfilepath), 2, (847, 2000))
@btime getcounts(calcenergy, eachevent(jldfilepath, checkhash=true), 2, (847, 2000))
rm(jldfilepath)

# Profile.print(mincount=100)
# Profile.clear()
