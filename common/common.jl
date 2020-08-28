println("Hello World!")

struct MaGeHits
    files::AbstractVector{AbstractString}
end
MaGeHits(filepath::AbstractString) = MaGeHits([filepath])
MaGeHits(dirpath::AbstractString, filepattern::Regex) = MaGeHits(
    [file for file in readdir(dirpath) if match(filepattern, file) !== nothing]
)
