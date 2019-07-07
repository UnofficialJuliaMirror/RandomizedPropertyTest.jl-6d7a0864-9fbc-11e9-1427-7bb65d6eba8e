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
julia> @quickcheck 10^6 (isnan(x) || sin(x+π) ≈ sin(x)) (x :: Float64)
```

It is also possible to test only variables inside of certain ranges:
```jldoctest
julia> @quickcheck (0 ≤ real(exp(2π * im * x) ≤ 1)) (x :: Range{Float64, 0, π})
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
