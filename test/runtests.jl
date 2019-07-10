using Test
using Documenter: makedocs
using RandomizedPropertyTest
import Random
import Logging


@testset "All tests" begin

@testset "Test failures" begin
  Logging.disable_logging(Logging.Warn)
  @test false == @quickcheck 10 false (x :: Int)
  @test false == @quickcheck 10 (x < 0) (x :: Int)
  @test_throws ErrorException @quickcheck error() (x :: Int)
  Logging.disable_logging(Logging.Info)
end

@testset "Test escaping" begin
  Logging.disable_logging(Logging.Warn)
  @test_throws UndefVarError @quickcheck (y == 4) (x :: Int)
  Logging.disable_logging(Logging.Info)
  begin
    y = 4
    @test @quickcheck (y == 4) (x :: Int)
  end
  begin
    struct SomeType end
    RandomizedPropertyTest.specialcases(_ :: Type{SomeType}) = Int8[1]
    RandomizedPropertyTest.generate(_ :: Random.AbstractRNG, _ :: Type{SomeType}) = Int8(1)
    @test @quickcheck (typeof(x) == Int8 && x == 1) (x :: SomeType)
  end
end

@testset "run doctests" begin
  @test begin makedocs(sitename="RandomizedPropertyTest.jl", strict=true); true; end
end

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

end # @testset "All tests"
