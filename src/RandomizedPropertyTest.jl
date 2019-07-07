module RandomizedPropertyTest

import Base.product
import Base.Iterators.flatten
using Logging: @logmsg, Error

export @quickcheck, Range, Disk


"""TODO: doc
"""
struct Range{T,a,b} end

struct Disk{T,z,r} end


"""TODO: doc
"""
macro quickcheck(n :: Integer, expr :: Expr, vartypes :: Vararg{Expr,N} where N)
  names = Symbol[]
  types = []

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
    f = $fexpr
    for $nametuple in cat(specialcases($typetuple), [generate($typetuple) for _ in 1:$n], dims=1)
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


macro quickcheck(expr :: Expr, args :: Vararg{Expr,N} where {N})
  esc(:(@quickcheck(1000, $expr, $(args...)))) # TODO maybe change to a different value?
end


"""TODO: doc
"""
function generate(types :: NTuple{N, DataType}) where {N}
  return tuple((generate(T) for T in types)...)
end


function generate(T :: DataType) :: T
  rand(T)
end


function generate(_ :: Type{T}) where {T<:AbstractFloat}
  return 100*tan(π*(rand()-1)) # Cauchy distribution
  # TODO: maybe choose mantissa and exponent seperately, then combine?
end


function generate(_ :: Type{Range{T,a,b}}) :: T where {T<:AbstractFloat,a,b}
  a + rand(T) * (b - a) # The endpoints are included via specialcases()
end


function generate(_ :: Type{Range{T,a,b}}) :: T where {T<:Integer,a,b}
  rand(a:b)
end


function generate(_ :: Type{Disk{Complex{T},z0,r}}) :: Complex{T} where {T<:AbstractFloat,z0,r}
  # generate point in unit disk
  z = Complex{T}(Inf, Inf)
  while !(abs(z) < 1)
    z = complex(2rand(T)-1, 2rand(T)-1)
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


function specialcases(_ :: Type{T}) :: Array{T,1} where {T <: Signed}
  smin = one(T) << (8 * sizeof(T) - 1)
  smax = smin - 1
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
