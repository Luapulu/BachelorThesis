## AbstractHit and Hit ##

abstract type AbstractHit end

const HitTuple = Tuple{Float32, Float32, Float32, Float32, Float32, Int32, Int32, Int32}

function Base.convert(::Type{HitTuple}, h::H)::HitTuple where {H<:AbstractHit}
    (location(h)..., energy(h), time(h), particleid(h), trackid(h), trackparentid(h))
end

function Base.show(io::IO, h::H) where {H<:AbstractHit}
    x, y, z = location(h)
    print(io, "Hit(", x, ", ", y, ", ", z, ", ")
    print(io, energy(h), ", ", time(h), ", ")
    print(io, particleid(h), ", ", trackid(h), ", ", trackparentid(h), ")")
end

struct Hit <: AbstractHit
    x::Float32
    y::Float32
    z::Float32
    E::Float32
    t::Float32
    particleid::Int32
    trackid::Int32
    trackparentid::Int32
end

location(h::Hit) = (h.x, h.y, h.z)
energy(h::Hit) = h.E
time(h::Hit) = h.t
particleid(h::Hit) = h.particleid
trackid(h::Hit) = h.trackid
trackparentid(h::Hit) = h.trackparentid


## Abstract Events ##

abstract type AbstractEvent{H<:AbstractHit} end

Base.IteratorSize(::Type{<:AbstractEvent}) = Base.HasLength()
Base.length(e::AbstractEvent) = hitcount(e)

Base.IteratorEltype(::Type{<:AbstractEvent}) = Base.HasEltype()
Base.eltype(e::Type{<:AbstractEvent{H}}) where {H} = H

Base.iterate(e::AbstractEvent) = iterate(hits(e))
Base.iterate(e::AbstractEvent, state) = iterate(hits(e), state)

function Base.:(==)(e1::AbstractEvent, e2::AbstractEvent)
    primarycount(e1) == primarycount(e2) && eventnum(e1) == eventnum(e2) && hits(e1) == hits(e2)
end

function Base.convert(::Type{Tuple}, e::AbstractEvent)
    hitvec = Vector{HitTuple}(undef, length(e))
    hitvec .= hits(e)
    return (hitvec, eventnum(e), hitcount(e), primarycount(e))
end

function Base.show(io::IO, e::AbstractEvent)
    if get(io, :compact, true)
        print(io, "Event(")
        print(io, "Array{", eltype(e), "}((", length(e), ",))")
        print(io, ", ", eventnum(e), ", ", hitcount(e), ", ", primarycount(e), ", ", index(e), ")")
    else
        print(io, "Event(")
        show(IOContext(io, :limit=>true, :typeinfo=>Vector{eltype(e)}), hits(e))
        print(io, ", ", eventnum(e), ", ", hitcount(e), ", ", primarycount(e), ", ", index(e), ")")
    end
end

function Base.show(io::IO, mime::MIME"text/plain", e::AbstractEvent)
    print(io, typeof(e), " with ")
    print(io, "eventnum: ", eventnum(e), ", hitcount: ", hitcount(e))
    print(io, ", primarycount: ", primarycount(e), ", index: ", index(e), " and hits: ")
    show(IOContext(io, :limit=>true), mime, hits(e))
end

energy(event::E) where {E<:AbstractEvent} = sum(energy, hits(event))


## Events ##

struct Event{H} <: AbstractEvent{H}
    hits::Vector{H}
    eventnum::Int
    hitcount::Int
    primarycount::Int
    fileindex::Int
    function Event{H}(hits, eventnum, hitcount, primarycount, fileindex) where {H}
        if length(hits) != hitcount
            throw(ArgumentError("hitcount $hitcount must equal number of hits $(length(hits))"))
        end
        return new(hits, eventnum, hitcount, primarycount, fileindex)
    end
end

function Event(hits::Vector{H}, eventnum::Int, hitcount::Int, primarycount::Int, fileindex::Int) where {H}
    Event{H}(hits, eventnum, hitcount, primarycount, fileindex)
end

hits(e::Event) = e.hits
index(e::Event) = e.fileindex
hitcount(e::Event) = e.hitcount
eventnum(e::Event) = e.eventnum
primarycount(e::Event) = e.primarycount
