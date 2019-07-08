using Test
using RandomizedPropertyTest

@testset "Check type for basic datatypes" begin
  for T in (Float16, Float32, Float64, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, ComplexF16, ComplexF32, ComplexF64)
    @testset "Check $T" begin
      @quickcheck 10^2 (typeof(x) == T) (x :: T)
    end
  end
end
