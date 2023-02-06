@testset "@computed mutable struct" begin
    @macroexpand @testset "SinCos" begin
        @eval @computed mutable struct MSinCos
            x::Float64
            thesincos::Tuple{Float64,Float64} = sincos(x)
        end
        @test Base.hasmethod(setproperty!, Tuple{MSinCos,Val{:x},<:Any})
        @test Base.hasmethod(computeproperty!, Tuple{MSinCos,Val{:thesincos}})

        ms = MSinCos(π / 2)
        @test ms.x == π / 2
        @test ms.thesincos == sincos(ms.x)
        @test (ms.x = π; ms.x) == Float64(π)
        @test ms.thesincos == sincos(ms.x)
        @test_throws ErrorException ms.thesincos = (0.0, 0.0)
    end

    @testset "Polar" begin
        @eval @computed mutable struct MPolar
            r
            phi
            x = r * cos(phi)
            y = r * sin(phi)
            one = x^2 + y^2 + cos(phi)^2 + sin(phi)^2
        end
        @test Base.hasmethod(setproperty!, Tuple{MPolar,Val{:r},<:Any})
        @test Base.hasmethod(setproperty!, Tuple{MPolar,Val{:phi},<:Any})
        @test Base.hasmethod(computeproperty!, Tuple{MPolar,Val{:x}})
        @test Base.hasmethod(computeproperty!, Tuple{MPolar,Val{:y}})
        @test Base.hasmethod(computeproperty!, Tuple{MPolar,Val{:one}})

        p = MPolar(1.0, 0.0)
        @test p.one ≈ 2.0
        p.phi = π / 4
        @test p.x ≈ p.y ≈ 1 / sqrt(2)
        @test p.one ≈ 2.0
    end

    @testset "Parametric" begin
        @eval @computed mutable struct MVectorAndNorm{T}
            v::Vector{T}
            norm::T = LinearAlgebra.norm(v)
        end
        vec_and_norm = MVectorAndNorm([1.0, 2.0, 3.0])
        @test vec_and_norm.norm ≈ sqrt(1 + 4 + 9)
        vec_and_norm.v = [1.0f0, 2.0f0]
        @test eltype(vec_and_norm.v) == Float64
    end

    ## Propagation ##
    @testset "Propagation" begin
        @eval @computed mutable struct MSomeRandoms
            lo::Float64
            hi::Float64
            x::Float64 = lo + (hi - lo) * rand()
            y = rand() + x
            z = y^2
        end
        sr = MSomeRandoms(1.0, 2.0)
        old_x, old_y, old_z = sr.x, sr.y, sr.z
        computeproperty!(sr, :x; propagate=false)
        @test old_x != sr.x && old_y == sr.y && old_z == sr.z
        old_x = sr.x
        computeproperty!(sr, :y; propagate=true)
        @test old_x == sr.x && sr.y != old_y && sr.z != old_z
    end
end