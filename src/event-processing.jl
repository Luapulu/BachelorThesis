eachevent(path::String) = EventFile(path)

save_events(events::Vector{MaGeEvent}, path::String) = savejld2(events, "events", path)
get_events(path::String) = loadjld2("events", path)

energy(event::MaGeEvent)::Float32 = sum(hit.E for hit in event)
