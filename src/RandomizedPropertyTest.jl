module RandomizedPropertyTest

using Random: MersenneTwister, AbstractRNG, randexp
import Base.product
import Base.Iterators.flatten
using Logging: @logmsg, Error

export @quickcheck, Range, Disk


"""TODO: doc
"""
# Note: Having a and b (the range endpoints) as type parameters is a bit unfortunate.
# It means that for ranges with the same type T but different endpoints, all relevant functions have to be recompiled.
# However, it is required because of generate(::NTuple{N, DataType}).
# Anyway, it is only for tests, so it should not be too much of a problem.
struct Range{T,a,b} end

struct Disk{T,z,r} end


"""TODO: doc
"""
macro quickcheck(args...)
  names = Symbol[]
  types = []

  length(args) >= 2 || error("Use as @quickcheck [n] expr type [...]")

  if args[1] isa Number
    n = args[1]
    args = args[2:end]
  elseif args[1] isa Expr && args[1].head == :call && args[1].args[1] == :^ && all(x->x isa Number, args[1].args[2])
    n = ^(args[1].args[2:end]...)
    args = args[2:length(args)]
  else
    n = 10^4
  end

  expr = args[1]
  vartypes = args[2:length(args)]

  length(vartypes) > 0 || error("No variable declared. Please use @test to test properties with no free variables.")

  for e in vartypes
    e isa Expr && e.head == :(::) || error("Invalid variable declaration `$e`.")
    if e.args[1] isa Symbol
      newsymbols = Symbol[e.args[1]]
    elseif e.args[1].head == :tuple && all(x->x isa Symbol, e.args[1].args)
      newsymbols = e.args[1].args
    else
      error("Invalid variable declaration `$e`.") # TODO: allow tuples of symbols
    end
    all(x -> !(x in names), newsymbols) || error("Duplicate declaration of $(e.args[1]).")
    for symb in newsymbols
      push!(names, symb)
      push!(types, e.args[2])
    end
  end

  nametuple = Expr(:tuple, names...)
  typetuple = esc(Expr(:tuple, types...)) # escaping is required for user-provided types
  exprstr = let io = IOBuffer(); print(io, expr); seek(io, 0); read(io, String); end
  namestrs = [String(n) for n in names]
  fexpr = esc(Expr(:(->), nametuple, expr)) # escaping is required for global (and other) variables in the calling scope

  return quote
    rng = $(MersenneTwister(0))
    f = $fexpr
    for $nametuple in Base.Iterators.flatten((specialcases($typetuple), (generate(rng, $typetuple) for _ in 1:$n)))
      try
        if !(f($nametuple...))
          exprstr = $exprstr
          if length($nametuple) == 1
            x = Expr(:(=), Symbol($namestrs[1]), $nametuple[1])
          else
            x = Expr(:tuple, (Expr(:(=), n, v) for (n, v) in zip($names, $nametuple))...)
          end
          @error "Property `$exprstr` does not hold for $x."
          break
        end
      catch exception
        exprstr = $exprstr
        if length($nametuple) == 1
          x = Expr(:(=), Symbol($namestrs[1]), $nametuple[1])
        else
          x = Expr(:tuple, (Expr(:(=), n, v) for (n, v) in zip($names, $nametuple))...)
        end
        #@logmsg Error "Error during @quickcheck of property `$exprstr` for $x."
        rethrow(exception)
      end
    end
  end
end


"""TODO: doc
"""
function generate(rng :: AbstractRNG, types :: NTuple{N, DataType}) where {N}
  return tuple((generate(rng, T) for T in types)...)
end


function generate(rng :: AbstractRNG, T :: DataType) :: T
  rand(rng, T)
end


function generate(rng :: AbstractRNG, _ :: Type{Array{T,N}}) :: Array{T,N} where {T,N}
  shape = Int.(round.(1 .+ 3 .* randexp(rng, N))) # empty array is a special case
  return rand(rng, T, shape...)
end


for (TI, TF) in Dict(Int16 => Float16, Int32 => Float32, Int64 => Float64)
  @eval begin
    function generate(rng :: AbstractRNG, _ :: Type{$TF})
      x = $TF(NaN)
      while isnan(x) || isinf(x)
        x = reinterpret($TF, rand(rng, $TI)) # generate a random int and pretend it is a float.
        # This gives an extremely broad distribution of floats.
        # Around 1% of the floats will have an absolute value between 1e-3 and 1e3.
      end
      return x
    end
  end
end


function generate(rng :: AbstractRNG, _ :: Type{Complex{T}}) where {T<:AbstractFloat}
  return complex(generate(rng, T), generate(rng, T))
end


function generate(rng :: AbstractRNG, _ :: Type{Range{T,a,b}}) :: T where {T<:AbstractFloat,a,b}
  a + rand(rng, T) * (b - a) # The endpoints are included via specialcases()
end


function generate(rng :: AbstractRNG, _ :: Type{Range{T,a,b}}) :: T where {T<:Integer,a,b}
  rand(rng, a:b)
end


function generate(rng :: AbstractRNG, _ :: Type{Disk{Complex{T},z0,r}}) :: Complex{T} where {T<:AbstractFloat,z0,r}
  # generate point in unit disk
  z = Complex{T}(Inf, Inf)
  while !(abs(z) < 1)
    z = complex(2rand(rng, T)-1, 2rand(rng, T)-1)
  end
  # scale
  return r*z+z0
end


"""TODO: doc
"""
function specialcases()
  return []
end


function specialcases(T :: DataType) :: Array{T,1}
  return []
end


function specialcases(types :: NTuple{N,DataType}) where {N}
  cases = [specialcases(T) for T in types]
  return reshape(collect(Base.product(cases...)), prod(length(c) for c in cases))
end


function specialcases(_ :: Type{Array{T,N}}) :: Array{Array{T,N},1} where {T,N}
  # TODO: For N ≥ 3, this uses huge amounts of memory!
  d0 = [Array{T,N}(undef, repeat([0], N)...)]
  d1 = [reshape([x], repeat([1], N)...) for x in specialcases(T)]
  d2_ = collect(Base.Iterators.product(repeat([specialcases(T)], 2^N)...))
  d2 = [Array{T,N}(reshape([d2_[i]...], repeat([2], N)...)) for i in 1:length(d2_)]
  return cat(d0, d1, d2, dims=1)
end


function specialcases(_ :: Type{T}) :: Array{T,1} where {T<:AbstractFloat}
  return [
    T(0.0),
    T(-0.0),
    T(-1.0),
    T(1.0),
    T(0.5),
    T(-0.5),
    T(1)/T(3),
    floatmax(T),
    floatmin(T),
    T(NaN),
    maxintfloat(T),
    one(T) / maxintfloat(T),
    -one(T) / maxintfloat(T),
    T(Inf),
    T(-Inf),
  ]
end


function specialcases(_ :: Type{Complex{T}}) :: Array{Complex{T},1} where {T <: AbstractFloat}
  return [complex(r, i) for r in specialcases(T) for i in specialcases(T)]
end


function specialcases(_ :: Type{T}) :: Array{T,1} where {T <: Signed}
  smin = one(T) << (8 * sizeof(T) - 1)
  smax = smin - one(T)
  return [
    T(0),
    T(1),
    T(-1),
    T(2),
    T(-2),
    smax,
    smin
  ]
end


function specialcases(_ :: Type{T}) :: Array{T} where {T <: Integer}
  return [
    T(0),
    T(1),
    T(2),
    ~T(0),
  ]
end


function specialcases(_ :: Type{Bool}) :: Array{Bool,1}
  return [
    true,
    false,
  ]
end


function specialcases(_ :: Type{Range{T,a,b}}) :: Array{T,1} where {T,a,b}
  return [
    T(a),
    T(b),
  ]
end


function specialcases(_ :: Type{Disk{Complex{T},z0,r}}) :: Array{Complex{T},1} where {T<:AbstractFloat,z0,r}
  return [
    Complex{T}(z0)
  ]
end


end
