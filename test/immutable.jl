@testset "@computed struct" begin
    @macroexpand @testset "SinCos" begin
        @eval @computed struct SinCos
            x::Float64
            thesincos::Tuple{Float64,Float64} = sincos(x)
        end
        @test Base.hasmethod(SinCos, Tuple{Float64})        
        ms = SinCos(π/2)
        @test ms.x == π/2
        @test ms.thesincos == sincos(ms.x)
        @test_throws ErrorException (ms.x = 0.0)
        @test_throws ErrorException ms.thesincos = (0.0,0.0)
    end
    
    @testset "Polar" begin
        @eval @computed struct Polar
            r
            phi
            x = r*cos(phi)
            y = r*sin(phi)
            two = x^2+y^2 + cos(phi)^2+sin(phi)^2
        end
        @test Base.hasmethod(Polar, Tuple{<:Any, <:Any})
    
        p = Polar(1.0, 0.0)
        @test p.two ≈ 2.0
        @test_throws ErrorException p.phi = π/4
        p = Polar(1.0, π/4)
        @test p.x ≈ p.y ≈ 1/sqrt(2)
        @test p.two ≈ 2.0
    end
    
    @testset "Parametric" begin
        @eval @computed struct VectorAndNorm{T}
            v::Vector{T}
            norm::T = LinearAlgebra.norm(v)
        end
        @test Base.hasmethod(VectorAndNorm, Tuple{Vector{Float64}})  
        @test Base.hasmethod(VectorAndNorm, Tuple{Vector{Float32}})
        vec_and_norm = VectorAndNorm([1.0,2.0,3.0])
        @test vec_and_norm.norm ≈ sqrt(1+4+9)
        @test_throws ErrorException vec_and_norm.v = [1f0,2f0]
    end
end