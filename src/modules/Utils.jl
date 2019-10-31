module Utils

export find_first_duplicate
# Must be array cannot be set because we need to preserve duplicates
function find_first_duplicate(vals::AbstractArray)
    seen_vals = Set()
    first_dup = nothing
    for val in vals
        if val in seen_vals
            first_dup = val
            break
        else
            push!(seen_vals, val)
        end
    end
    isnothing(first_dup) ? nothing : first_dup
end

end # module
