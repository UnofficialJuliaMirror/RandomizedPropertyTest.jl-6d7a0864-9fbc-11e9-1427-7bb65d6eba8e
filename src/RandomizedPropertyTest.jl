module RandomizedPropertyTest

import Base.product
import Base.Iterators.flatten

export @quickcheck


"""TODO: doc
"""
macro quickcheck(n :: Integer, expr :: Expr, vartypes :: Vararg{Expr,N} where {N})
  names = Symbol[]
  types = Symbol[]

  for e in vartypes
    e isa Expr && e.head == :(::) || error("TODO")
    e.args[1] isa Symbol && e.args[2] isa Symbol || error("TODO")
    !(e.args[1] in names) || error("Duplicate variable $(e.args[1]).")
    push!(names, e.args[1])
    push!(types, e.args[2])
  end

  nametuple = Expr(:tuple, names...)
  typetuple = Expr(:tuple, types...)

  exprstr = let io = IOBuffer(); print(io, expr); seek(io, 0); read(io, String); end

#  println(typeof(expr), ", ", expr)
#  Expr(:call,
#    :quickcheck,
#    :($nametuple -> ($expr)),
#    Expr(:quote, expr),
#    :(tuple(names...)),
#    typetuple,
#    n)
  :(quickcheck($nametuple -> ($expr), $exprstr, $(tuple(names...)), $typetuple, $n))
end

macro quickcheck(expr :: Expr, args :: Vararg{Expr,N} where {N})
  :(@quickcheck(100, $expr, $(args...))) # TODO maybe change to a different value?
end

#function quickcheck(f :: Function, expr ::Expr, varnames :: NTuple{N,Symbol}, types :: NTuple{N,DataType}, n) where {N}
function quickcheck(f :: Function, expr ::String, varnames :: NTuple{N,Symbol}, types :: NTuple{N,DataType}, n) where {N}
  #expr = expr.args[1] # undo quote
  for vars in cat(specialcases(types), [generate(types) for _ in 1:n], dims=1)
    if !f(vars...) # TODO: catch errors (exceptions / f(vars...) is not a bool
      if length(varnames) == 0
        @error "Property `$expr` does not hold."
      elseif length(varnames) == 1
        @error "Property `$expr` does not hold for $(Expr(:(=), varnames[1], vars))."
      else
        x = Expr(:tuple, (Expr(:(=), n, v) for (n, v) in zip(varnames, vars))...)
        @error "Property `$expr` does not hold for $x."
        # TODO: error macro give wrong line number.
        # -> remove this function, put it inside the macro (generate the code)
      end
      return
    end
  end
end


"""TODO: doc
"""
function generate(types :: NTuple{N, DataType}) where {N}
  return tuple((generate(T) for T in types)...)
end


function generate(T)
  rand(T) # TODO: choose a different distribution?
end


"""TODO: doc
"""
function specialcases()
  return []
end


function specialcases(_)
  return []
end


function specialcases(types :: NTuple{N,DataType}) where {N}
  cases = [specialcases(T) for T in types]
  return reshape(collect(Base.product(cases...)), prod(length(c) for c in cases))
end


function specialcases(_ :: Type{T}) where {T<:AbstractFloat}
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
  ]
end


function specialcases(_ :: Type{T}) where {T <: Signed}
  smin = one(T) << (8 * sizeof(T) - 1)
  smax = min - 1
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


function specialcases(_ :: Type{T}) where {T <: Integer}
  return [
    T(0),
    T(1),
    T(2),
    ~T(0),
  ]
end


end
