# ComputedFields

[![Build Status](https://github.com/skleinbo/ComputedFields.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/skleinbo/ComputedFields.jl/actions/workflows/CI.yml?query=branch%3Amain)

Convenient overloading of `setproperty!` for lightweight reactive structs.

This package exports the macro

## `@computed`

Annotating a (mutable) struct definition with `@computed` facilitates the definition of fields (_dependent variables_), which are automatically computed when an instance is created. If the struct is declared as `mutable`, the corresponding dependent fields are re-computed whenever an _independent variable (field)_ is updated. Care is taken to ensure the correct order of computations.

The macro defines

* The struct (e.g. `TheType`) with field types as annotated.
* A constructor `TheType(indep_vars...)`
* __(`mutable` only)__ A method `computeproperty!(::TheType, dep_var::Symbol)` that recomputes the field `dep_var`. The computation propagates and triggers re-computations downstream in the computational graph by default. Set `propagate=false` if it should not.
* __(`mutable` only)__ A method `setproperty!(::TheType, indep_var::Symbol, value)` that sets `field` to `value` and triggers computation of dependent variables.

### Examples

```julia
julia> @computed struct SinCos
    x::Float64
    thesincos::Tuple{Float64,Float64} = sincos(x)
end

julia> sc = SinCos(pi/2)
SinCos(1.5707963267948966, (1.0, 6.123233995736766e-17))

## Mutable

julia> @computed mutable struct MSinCos
    x::Float64
    thesincos::Tuple{Float64,Float64} = sincos(x)
end

julia> sc = MSinCos(0.0)
MSinCos(0.0, (0.0, 1.0))

julia> sc.x = pi/2
1.5707963267948966

julia> sc.thesincos
(1.0, 6.123233995736766e-17)

# trying to set a computed field errors
julia> sc.thesincos = (0.0, 0.0)
ERROR: cannot set calculated field thesincos
[...]
```

Parametric types are supported:

```julia
julia> @computed mutable struct VectorAndNorm{N,T}
           v::SVector{N,T}
           norm::T = LinearAlgebra.norm(v)
       end

julia> vec_and_norm = VectorAndNorm(@SVector [1.0,2.0,3.0])
VectorAndNorm{3, Float64}([1.0, 2.0, 3.0], 3.7416573867739413)

julia> vec_and_norm.norm
3.7416573867739413
```

## (Current) Limitations

* It's the user's responsibility to make sure no circular dependencies amongst fields are introduced.
* Computed fields must be explicitly type annotated, or they default to `Any`.
* Re-computations are triggered by mutating fields. Thus, e.g.
  
  ```julia
  @computed mutable struct VectorMax
    v::Vector{Float64}
    max::Float64 = maximum(v)
  end

  vm = VectorMax([1.0,2.0,3.0])
  # vm.max == 3.0
  vm.v[1] = 10.0
  # vm.max is _not_ 10.0 now
  # call computeproperty!(vm, :max) explicitly instead.
  ```

  does not work.
* Updating multiple independent fields simultaneously is not (yet) supported.
* Because an inner constructor is automatically defined, you cannot provide your own.

## To-do

* [ ] Support immutable struct: setting an independent field returns a new instance.
* [ ] Multi-update
* [x] Propagating re-computation of dependent fields.
