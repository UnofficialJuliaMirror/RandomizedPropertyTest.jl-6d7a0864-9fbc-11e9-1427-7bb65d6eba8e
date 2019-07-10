using Test
using Documenter: makedocs
using RandomizedPropertyTest

@testset "Check type for basic datatypes" begin
  for T in (Bool, Float16, Float32, Float64, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, ComplexF16, ComplexF32, ComplexF64)
    @testset "Check $T" begin
      @test @quickcheck 10^2 (typeof(x) == T) (x :: T)
    end
  end
end

@testset "Check special cases dispatch for basic datatypes" begin
  for T in (Float16, Float32, Float64)
    @test any(isnan, RandomizedPropertyTest.specialcases(T))
  end
  for T in (Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64)
    @test 0 in RandomizedPropertyTest.specialcases(T)
  end
  for T1 in (Float16, Float32, Float64)
    for T2 in (Float16, Float32, Float64)
      @test any(tup->any(isnan, tup), RandomizedPropertyTest.specialcases((T1, T2)))
    end
  end
end

@testset "Check Range{}" begin
  for T in (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128)
    @test @quickcheck (typeof(x) == T) (x :: Range{T, 0, 1})
    @test @quickcheck (0 ≤ x ≤ 42) (x :: Range{T, 0, 42})
    @test 14 in RandomizedPropertyTest.specialcases(Range{T, 14, 56})
    @test 56 in RandomizedPropertyTest.specialcases(Range{T, 14, 56})
  end
end

@testset "Check Disk{}" begin
  for T in (ComplexF16, ComplexF32, ComplexF64)
    @test @quickcheck (typeof(z) == T) (z :: Disk{T, 0, 1})
    @test @quickcheck (abs(z-4-2im) < 5) (z :: Disk{T, 4+2im, 5})
    @test (3-2im) in RandomizedPropertyTest.specialcases(Disk{T, 3-2im, 9})
  end
end

@testset "Test array type" begin
  for T in (Bool, Float16, Float32, Float64, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, ComplexF16, ComplexF32, ComplexF64)
    @test @quickcheck 10 (typeof(x) == Array{T,1}) (x :: Array{T,1})
    @test @quickcheck 10 (typeof(x) == Array{T,2}) (x :: Array{T,2})
    #@test @quickcheck 10 (typeof(x) == Array{T,3}) (x :: Array{T,3})
  end
end

#@testset "Check doctests" begin
#  @test_nowarn makedocs(sitename="RandomizedPropertyTest.jl", strict=true)
#end
makedocs(sitename="RandomizedPropertyTest.jl", strict=true)
