function appendrawAoEhist!(hist, event_path::AbstractString, signal_path::AbstractString)
    sgnls = load_signals(SignalDict, signal_path)

    for event in MaGe.loadstreaming(event_path)
        if !ismissing(sgnls[event])
            E = energy(event)
            push!(hist, (E, getA(sgnls[event]) / E))
        end
    end

    hist
end

function appendrawAoEhist!(
    hist,
    event_paths::Vector{<:AbstractString},
    signal_paths::Vector{<:AbstractString},
)
    for (ep, sp) in zip(event_paths, signal_paths)
        appendrawAoEhist!(hist, ep, sp)
    end

    hist
end
