TODO


Examples
--------

Test that the square of a float is nonnegative.

```jldoctest
julia> @quickcheck (x^2 ≥ 0) (x :: Float64)
┌ Error: Property `x ^ 2 ≥ 0` does not hold for x = NaN.
└ @ RandomizedPropertyTest ~/store/zeug/RandomizedPropertyTest/src/RandomizedPropertyTest.jl:52
```

It fails because we did not think of NaN.
After refining our property, the test succeeds:
```jldoctest
julia> @quickcheck (isnan(x) || x^2 ≥ 0) (x :: Float64)
```
There is no output (and no error), which means the property holds for all inputs that were tested.

Next, we will test Julia's builtin sine function, with large number of tests:
```jldoctest
julia> @quickcheck 10^6 (isnan(x) || sin(x+2π) ≈ sin(x)) (x :: Float64)
```
# TODO: This fails now.

It is also possible to test only variables inside of certain ranges:
```jldoctest
julia> @quickcheck (-1 ≤ real(exp(2π * im * x)) ≤ 1) (x :: Range{Float64, 0, π})
```

Next, let's test the geometric sum of the complex numbers inside the unit disk (the border is excluded).
```jldoctest
julia> nmax(ε, z) = if z == 0; 0 else Int(round(log10(ε)/log10(abs(z)))) end
nmax (generic function with 1 method)

julia> @quickcheck sum(z^k for k in 0:nmax(1e-8, z)) ≈ 1/(1-z) (z :: Disk{Complex{Float64}, 0, 1})
```

There is a convenient syntax for declaring multiple variables of the same type.
```jldoctest
julia> using LinearAlgebra

julia> @quickcheck (norm([x,y,z]) ≥ 0 || any(isnan, [x,y,z])) ((x, y, z) :: Float64)
```


Custom Distributions or Datatypes
---------------------------------


To use `@quickcheck` with a custom datatype, or to generate random samples from a specific distribution, import and specialize the functions `RandomizedPropertyTest.generate` and `RandomizedPropertyTest.specialize`.

In this example, we generate floats from the normal distribution.
```
julia> import RandomizedPropertyTest.specialcases, RandomizedPropertyTest.generate

julia> struct NormalFloat{T}; end # define a new type; required for correct dispatch

julia> RandomizedPropertyTest.specialcases(_ :: Type{NormalFloat{T}}) where {T<:AbstractFloat} = RandomizedPropertyTest.specialcases(T) # inherit special cases

julia> RandomizedPropertyTest.generate(_ :: Type{NormalFloat{T}}) where {T<:AbstractFloat} = randn(T)

julia> @quickcheck (typeof(x) == Float32) (x :: NormalFloat{Float32})
```

Note that `specialcases` returns a list of special cases which are always checked.
For multiple variables, every combination of special cases is tested.
Make sure to limit the number of special cases to avoid problems due to combinatorial explosion.

The function `generate` should return a single random specimen of the datatype.


TODO
----

- Use a PRNG for generation (by default), for reproducibility
- Write generators and special cases for all the things. (see how QuickCheck does it?)
- Custom specific generators for types for which a generic generator already exists (e. g. for ranges / prob. distributions for floats) (how does QuickCheck solve this?)
- Change Range{T,a,b} to Range{T} with members a, b (to prevent recompilation of generate(...) for the same type, but different endpoints)
- parallel checking?
- special cases for certain properties (like equality).
  Example:
      @quickcheck let a :: Float64, b :: Float64, c :: Float64; a + (b + c) == (a + b) + c; end
  should give something like:
      Property a + (b + c) == (a + b) + c does not hold for a = 1.0, b = 1.11e-16, c = 1.11e-16:
      1 + (1.11e-16 + 1.11e-16) == (1 + 1.11e-16) + 1.11e-16 evaluates to 1.000...02 == 1.0, which is false.
  (and similarly for >, <, etc.)
