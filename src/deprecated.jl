# Introduced in 0.6
Base.@deprecate_binding(
    AbstractContext,
    Assertion,
    false,
    "Imputation contexts have been replaced with independent Impute.Assertion types.",
)
Base.@deprecate Context(; limit=1.0, kwargs...) Threshold(limit) false
Base.@deprecate WeightedContext(wv; limit=1.0, kwargs...) Threshold(limit; weights=wv) false

# A couple utility methods to avoid messing up var and obs dimensions
# NOTE: We aren't deprecating these as they were always internal function that weren't
# intended for public use.
obsdim(dims::Int) = dims
vardim(dims::Int) = dims == 1 ? 2 : 1

function obswise(data::AbstractMatrix; dims=1)
    return (selectdim(data, obsdim(dims), i) for i in axes(data, obsdim(dims)))
end

function varwise(data::AbstractMatrix; dims=2)
    return (selectdim(data, vardim(dims), i) for i in axes(data, vardim(dims)))
end

function filterobs(f::Function, data::AbstractMatrix; dims=1)
    mask = [f(x) for x in obswise(data; dims=dims)]
    return dims == 1 ? data[mask, :] : data[:, mask]
end

function filtervars(f::Function, data::AbstractMatrix; dims=2)
    mask = [f(x) for x in varwise(data; dims=dims)]
    return dims == 1 ? data[:, mask] : data[mask, :]
end

"""
    DropObs()

[Deprecated] Removes missing observations from the `AbstractArray` or `Tables.table`
provided.

# Example
```jldoctest
julia> using Impute: DropObs, impute

julia> M = [1.0 2.0 missing missing 5.0; 1.1 2.2 3.3 missing 5.5]
2×5 Array{Union{Missing, Float64},2}:
 1.0  2.0   missing  missing  5.0
 1.1  2.2  3.3       missing  5.5

julia> impute(M, DropObs(); dims=2)
2×3 Array{Union{Missing, Float64},2}:
 1.0  2.0  5.0
 1.1  2.2  5.5
```
"""
struct DropObs <: Imputor
    function DropObs()
        Base.depwarn(
            "Impute.DropObs is deprecated in favour of the more general Impute.Filter.",
            :DropObs
        )
        return new()
    end
end

# Special case impute! for vectors because we know filter! will work
impute!(data::Vector, imp::DropObs) = Base.filter!(!ismissing, data)

function impute!(data::Vector{<:NamedTuple}, imp::DropObs)
    return Base.filter!(r -> all(!ismissing, propertyvalues(r)), data)
end

impute(data::AbstractVector, imp::DropObs) = Base.filter(!ismissing, data)

function impute(data::Vector{<:NamedTuple}, imp::DropObs)
    return Base.filter(r -> all(!ismissing, propertyvalues(r)), data)
end

function impute(data::AbstractMatrix{Union{T, Missing}}, imp::DropObs; dims=1) where T
    return filterobs(obs -> all(!ismissing, obs), data; dims=dims)
end

function impute(table, imp::DropObs)
    @assert istable(table)
    rows = Tables.rows(table)

    # Unfortunately, we'll need to construct a new table
    # since Tables.rows is just an iterator
    filtered = Iterators.filter(rows) do r
        all(!ismissing, propertyvalues(r))
    end

    table = materializer(table)(filtered)
    return table
end


"""
    DropVars()


[Deprecated] Finds variables with too many missing values in a `AbstractMatrix` or
`Tables.table` and removes them from the input data.

# Examples
```jldoctest
julia> using Impute: DropVars, impute

julia> M = [1.0 2.0 missing missing 5.0; 1.1 2.2 3.3 missing 5.5]
2×5 Array{Union{Missing, Float64},2}:
 1.0  2.0   missing  missing  5.0
 1.1  2.2  3.3       missing  5.5

julia> impute(M, DropVars(); dims=2)
1×5 Array{Union{Missing, Float64},2}:
 1.1  2.2  3.3  missing  5.5
```
"""
struct DropVars <: Imputor
    function DropVars()
        Base.depwarn(
            "Impute.DropVars is deprecated in favour of the more general Impute.Filter.",
            :DropObs
        )
        return new()
    end
end

function impute!(data::Vector{<:NamedTuple}, imp::DropVars)
    return materializer(data)(impute(Tables.columns(data), imp))
end

function impute(data::AbstractMatrix{Union{T, Missing}}, imp::DropVars; dims=1) where T
    return filtervars(data; dims=dims) do vars
        all(!ismissing, vars)
    end
end

function impute(table, imp::DropVars)
    istable(table) || throw(MethodError(impute, (table, imp)))
    cols = Tables.columns(table)

    cnames = Iterators.filter(propertynames(cols)) do cname
        all(!ismissing, getproperty(cols, cname))
    end

    selected = TableOperations.select(table, cnames...)
    table = materializer(table)(selected)
    return table
end

function impute!(data::AbstractMatrix{Union{T, Missing}}, imp::Union{DropObs, DropVars}) where T
    data = impute(data, imp)
    return data
end

function impute!(data::AbstractVector{Union{T, Missing}}, imp::Union{DropObs, DropVars}) where T
    data = impute(data, imp)
    return data
end

impute!(data, imp::Union{DropObs, DropVars}) = impute(data, imp)
