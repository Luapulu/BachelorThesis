function filemap(func, filepaths::AbstractArray{<:AbstractString}; batch_size=1)
    return pmap(func, filepaths, batch_size=batch_size)
end

function getbin(val, bins::Int, limits::Tuple{T, T}) where T <: Real
    lower, upper = limits
    val < lower && return 1
    val > upper && return bins + 2
    step = (upper - lower) / (bins - 1)
    return round(Int, (val - lower) / step) + 2
end

function getcounts(func, f::MaGeFile, bins::Int, limits::Tuple{T, T}) where T <: Real
    freq = Vector{Int64}(zeros(bins+2))
    for event in f
        freq[getbin(func(event), bins, limits)] += 1
    end
    return freq
end

calcenergy(event::MaGeEvent)::Float32 = sum(hit.E for hit in event)

"""Convert to detector coordinates [mm]"""
function todetectorcoords(x, y, z, xtal_length)
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length
    return x, y, z
end
