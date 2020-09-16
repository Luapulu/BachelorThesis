energy(event::MaGeEvent)::Float32 = sum(hit.E for hit in event)
