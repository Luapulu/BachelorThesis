## AbstractHit ##

abstract type AbstractHit end

function Base.show(io::IO, h::H) where {H<:AbstractHit}
    x, y, z = location(h)
    print(io, H, "(", x, ", ", y, ", ", z, ", ")
    print(io, energy(h), ", ", time(h), ", ")
    print(io, particleid(h), ", ", trackid(h), ", ", trackparentid(h), ")")
end


## Hit ##

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

function Hit(nt::NamedTuple)
    Hit(nt[:x], nt[:y], nt[:z], nt[:E], nt[:t], nt[:particleid], nt[:trackid], nt[:trackparentid])
end
Base.convert(::Type{Hit}, nt::NamedTuple) = Hit(nt)

Hit(t::Tuple) = Hit(t...)
Base.convert(::Type{Hit}, t::Tuple) = Hit(t)

location(h::Hit) = (h.x, h.y, h.z)
energy(h::Hit) = h.E
Base.time(h::Hit) = h.t
particleid(h::Hit) = h.particleid
trackid(h::Hit) = h.trackid
trackparentid(h::Hit) = h.trackparentid

## Abstract Event ##

abstract type AbstractEvent end

Base.IteratorSize(::Type{<:AbstractEvent}) = Base.HasLength()
Base.length(e::AbstractEvent) = hitcount(e)

Base.IteratorEltype(::Type{<:AbstractEvent}) = Base.HasEltype()

Base.iterate(e::AbstractEvent) = iterate(hits(e))
Base.iterate(e::AbstractEvent, state) = iterate(hits(e), state)

Base.getindex(e::AbstractEvent, i) = getindex(hits(e), i)
Base.lastindex(e::AbstractEvent) = lastindex(hits(e))

function Base.show(io::IO, e::AbstractEvent)
    print(io, "Event(")
    print(io, eventnum(e), ", ", hitcount(e), ", ", primarycount(e), ", ")
    show(IOContext(io, :limit => true, :compact => true), hits(e))
    print(")")
end

function Base.show(io::IO, mime::MIME"text/plain", e::AbstractEvent)
    print(io, typeof(e), " with ")
    print(io, "eventnum: ", eventnum(e), ", hitcount: ", hitcount(e))
    print(io, ", primarycount: ", primarycount(e), " and hits:\n")
    show(IOContext(io, :limit => true), mime, hits(e))
end

energy(event::E) where {E<:AbstractEvent} = sum(energy, hits(event))


## Event ##

struct Event{V<:AbstractVector} <: AbstractEvent
    eventnum::Int32
    hitcount::Int32
    primarycount::Int32
    hits::V
    function Event{V}(eventnum, hitcount, primarycount, hits) where {V<:AbstractVector}
        if length(hits) == hitcount
            return new(eventnum, hitcount, primarycount, hits)
        end
        throw(ArgumentError("hitcount $hitcount must equal length of hit vector $(length(hits))"))
    end
end

function Event(eventnum, hitcount, primarycount, hits::V) where {V<:AbstractVector}
    Event{V}(eventnum, hitcount, primarycount, hits)
end

Base.eltype(::Type{Event{V}}) where {V} = eltype(V)

hits(e::Event) = e.hits
hitcount(e::Event) = e.hitcount
eventnum(e::Event) = e.eventnum
primarycount(e::Event) = e.primarycount


## Event Collection ##

abstract type EventCollection{E<:AbstractEvent} end

Base.IteratorSize(::Type{EventCollection}) = Base.SizeUnknown()

Base.IteratorEltype(::Type{EventCollection}) = Base.HasEltype()
Base.eltype(::Type{EventCollection{E}}) where {E} = E


## Signal Collection ##

abstract type SignalCollection end

Base.IteratorSize(::Type{SignalCollection}) = Base.HasLength()

Base.IteratorEltype(::Type{SignalCollection}) = Base.HasEltype()
Base.eltype(::Type{SignalCollection}) = AbstractVector{Float32}
