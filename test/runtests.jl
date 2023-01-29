using ComputedFields
import LinearAlgebra
using Test

@computed mutable struct SinCos
    x::Float64
    thesincos::Tuple{Float64,Float64} = sincos(x)
end
@testset "SinCos" begin
    @test Base.hasmethod(setproperty!, Tuple{SinCos, Val{:x}, <:Any})
    @test Base.hasmethod(calculateproperty!, Tuple{SinCos, Val{:thesincos}})

    ms = SinCos(π/2)
    @test ms.x == π/2
    @test ms.thesincos == sincos(ms.x)
    @test (ms.x = π; ms.x) == Float64(π)
    @test ms.thesincos == sincos(ms.x)
    @test_throws ErrorException ms.thesincos = (0.0,0.0)
end

@computed mutable struct Polar
    r
    phi
    x = r*cos(phi)
    y = r*sin(phi)
    one = x^2+y^2 + cos(phi)^2+sin(phi)^2
end
@testset "Polar" begin
    @test Base.hasmethod(setproperty!, Tuple{Polar, Val{:r}, <:Any})
    @test Base.hasmethod(setproperty!, Tuple{Polar, Val{:phi}, <:Any})
    @test Base.hasmethod(calculateproperty!, Tuple{Polar, Val{:x}})
    @test Base.hasmethod(calculateproperty!, Tuple{Polar, Val{:y}})
    @test Base.hasmethod(calculateproperty!, Tuple{Polar, Val{:one}})

    p = Polar(1.0, 0.0)
    @test p.one ≈ 2.0
    p.phi = π/4
    @test p.x ≈ p.y ≈ 1/sqrt(2)
    @test p.one ≈ 2.0
end

@computed mutable struct VectorAndNorm{T}
    v::Vector{T}
    norm::T = LinearAlgebra.norm(v)
end
@testset "Parametric" begin
    vec_and_norm = VectorAndNorm([1.0,2.0,3.0])
    @test vec_and_norm.norm ≈ sqrt(1+4+9)
    vec_and_norm.v = [1f0,2f0]
    @test eltype(vec_and_norm.v) == Float64
end


