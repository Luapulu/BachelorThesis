import Base: iterate


struct MaGeHitIter
    files::AbstractVector{AbstractString}
end
MaGeHitIter(filepath::AbstractString) = MaGeHitIter([filepath])

function MaGeHitIter(dirpath::AbstractString, filepattern::Regex)
    MaGeHitIter([file for file in readdir(dirpath, join=true) if occursin(filepattern, file)])
end

function iterate(iter::MaGeHitIter, state)
    rowvector, fileindex, rowindex = state
    fileindex > length(iter.files) && return nothing
    if rowindex > length(rowvector)
        rowindex = 1
        fileindex += 1
        rowvector = readlines(iter.files[fileindex])
    end
    return rowvector[rowindex], (rowvector, fileindex, rowindex+1)
end
iterate(iter::MaGeHitIter) = iterate(iter::MaGeHitIter, (readlines(first(iter.files)), 1, 1))
