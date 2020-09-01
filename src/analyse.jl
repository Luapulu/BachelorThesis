function filemap(func, filepaths::AbstractArray{String})
    return pmap(func, getevents(f) for f in filepaths)
end

calcenergy(event::MaGeEvent) = sum(hit.E for hit in event)

function getbin(val, bins::Int, limits::Tuple{T, T}) where T <: Real
    lower, upper = limits
    val < lower && return 1
    val > upper && return bins + 2
    step = (upper - lower) / (bins - 1)
    return Int64(fld(val - lower, step) + 2)
end

function getcounts(func, f::MaGeFile, bins::Int, limits::Tuple{T, T}) where T <: Real
    freq = Vector{Int64}(zeros(bins+2))
    for event in f
        freq[getbin(func(event), bins, limits)] += 1
    end
    return freq
end
