`RandomizedPropertyTest.jl`
---------------------------

`RandomizedPropertyTest.jl` is a test framework for testing program properties with random (as well as special pre-defined) inputs.


Examples
--------

The first property we test is that the square of a double-precision floating point number is nonnegative.
```jldoctest
julia> @quickcheck (x^2 ≥ 0) (x :: Float64)
┌ Error: Property `x ^ 2 ≥ 0` does not hold for x = NaN.
└ @ RandomizedPropertyTest ~/store/zeug/RandomizedPropertyTest/src/RandomizedPropertyTest.jl:52
false
```
The macro prints a message which gives a failing input: NaN.
After refining the property, the test succeeds:
```jldoctest
julia> @quickcheck (isnan(x) || x^2 ≥ 0) (x :: Float64)
true
```
The macro returns true, which means the property holds for all inputs which were tested.
Because the macro returns a boolean, it can be used together with the `@test` macro for automated testing.

Next, we will test Julia's builtin trigonometric functions, for floats inside of a certain range:
```jldoctest
julia> @quickcheck (sin(x + π/2) ≈ cos(x)) (x :: Range{Float64, 0, 2π})
true
```
Note that ranges are inclusive, and both endpoints are treated as special cases which are always tested.

Tests can use multiple variables.
```
julia> @quickcheck (a+b == b+a) (a :: Int) (b :: Int)
true
```

There is convenient syntax for declaring multiple variables of the same type.
```jldoctest
julia> using LinearAlgebra

julia> @quickcheck (norm([x,y,z]) ≥ 0 || any(isnan, [x,y,z])) ((x, y, z) :: Float64)
true
```

To increase (or reduce) the number of random tests, we can simply give the number as first argument.
```jldoctest
@quickcheck 10^6 (sum(x^k/factorial(k) for k in 0:20) ≈ exp(x)) (x :: Range{Float64, -2, 2})
true
```
At the moment, only numbers and powers of numbers are supported.
Other expressions (including variables) are not supported at this time.

Next, let's test the value of the geometric series for complex numbers inside the unit disk (the boundary is excluded).
```jldoctest
julia> let nmax(ε, z) = if z == 0; 0 else Int(round(log10(ε)/log10(abs(z)))) end
           @quickcheck sum(z^k for k in 0:nmax(√eps(1.0), z)) ≈ 1/(1-z) (z :: Disk{Complex{Float64}, 0, 1})
       end
true
```

Support for Arrays is also available:
```jldoctest
julia> using LinearAlgebra

julia> @quickcheck (any(isnan, A) || any(isinf, A) || all(λ->λ≥-0.001, eigvals(Symmetric(A * transpose(A))))) (A :: Array{Float32, 2})
true
```
At this time, support for arrays with more than three dimensions is limited.


Custom Distributions or Datatypes
---------------------------------


To use `@quickcheck` with a custom datatype, or to generate random samples from a specific distribution, import and specialize the functions `RandomizedPropertyTest.generate` and `RandomizedPropertyTest.specialize`.

In this example, we generate floats from the normal distribution.
```
julia> import RandomizedPropertyTest.specialcases, RandomizedPropertyTest.generate, Random.AbstractRNG

julia> struct NormalFloat{T}; end # Define a new type; it does not need to be a parametric type.

julia> RandomizedPropertyTest.specialcases(_ :: Type{NormalFloat{T}}) where {T<:AbstractFloat} = RandomizedPropertyTest.specialcases(T) # Inherit special cases from the "regular" type.

julia> RandomizedPropertyTest.generate(rng :: Random.AbstractRNG, _ :: Type{NormalFloat{T}}) where {T<:AbstractFloat} = randn(rng, T) # Define random generation using the normal distribution.

julia> @quickcheck (typeof(x) == Float32) (x :: NormalFloat{Float32}) # Use the new type like the built-in types.
true
```

Note that `specialcases` returns a 1d array of special cases which are always checked.
For multiple variables, every combination of special cases is tested.
Make sure to limit the number of special cases to avoid problems due to combinatorial explosion - for more than one variable, all combinations of all special cases are checked.

The function `generate` should return a single random specimen of the datatype.
Note that it takes a `AbstractRNG` argument.
You do not technically have to use it, but you should.
If you do, this makes tests (and test failures) reproducible, which probably helps debugging.


Bugs and caveats
----------------

- Performance is quite low: `@quickcheck 10^6 true (x :: Int)` takes around 0.8 seconds on the author's laptop.
- Combinatorial explosion of special cases makes working with many variables very difficult.
  For example, using nine `Float64` variables to check properties of 3x3 matrices generates 5*10^9 special cases.
- Testing is not exhaustive:
  You should not rely on `@quickcheck` to test every possible input value, e. g. if the only variable for which you are testing is a small integer range.


Similar work
------------

- [`QuickCheck`](https://github.com/nick8325/quickcheck) is a property testing framework for Haskell programs.
  It is great but cannot test Julia programs.
  Hence this project.
- (https://github.com/pao/QuickCheck.jl)[`Quickcheck.jl`] is a property testing implementation for Julia programs, also inspired by [https://github.com/nick8325/quickcheck](QuickCkeck).
  At the time of writing, it seems to be unmaintained since five years and is not compatible with Julia version 1 (though a pull request which fixes this is pending).
  It also does not specifically test special values like NaN or empty arrays, which are often handled incorrectly, and which are not easily found through purely random testing.


Version
-------

`RandomizedPropertyTest.jl` follows [semanting versioning v2.0.0](https://semver.org/).
The current version is 0.0.1.


TODO
----

- XXX: Add actual docstrings for `@quickcheck`, `generate`, `specialcases`, `Range`, `Disk`.
- XXX: Fix memory issues.
- XXX: Automated testing of jldocstrings in this file and the source file.
- Write generators and special cases for all the things (see how QuickCheck does it?):
  - square matrices
  - symmetric matrices
  - Hermitian matrices
  - unitary matrices
  - n-tuples
  - strings
  - rational numbers
  - Maybe also for certain distributions: normal, exponential, cauchy, lognormal, ...
  - ???
- To test numerical algorithms, there should be convenient syntax to test matrices and vectors of certain corresponding sizes.
  Maybe something like `@quickcheck ((A,v) = x; transpose(v) * A * v ≥ 0) (x :: MatrixAndVector{Float64})`.
- Figure out how to achieve parallel checking without losing reproducibility of test cases
  Also figure out how to make parallel checking convenient (`@parallel @quickcheck expr types`?)


How does it work?
-----------------

Here is a simplified version (mostly for the benefit of the author):

```jldoctest
julia> macro evaluate(expr, argname, arg)
           fexpr = esc(Expr(:(->), argname, expr)) # define a closure in the calling scope
           Expr(:call, fexpr, arg) # call it
       end
@evaluate (macro with 1 method)

julia> y = 2
2

julia> @evaluate (4*x+y) x 10
42
```
