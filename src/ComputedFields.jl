module ComputedFields

# Write your package code here.
import Base: in, getindex, show
import Base.Cartesian: @nexprs
import MacroTools: @capture, prewalk, postwalk

export @computed

function order(dep_vars::Dict{Symbol,<:Any}, var::Symbol)
    order = Symbol[var]
    dep_vars = deepcopy(dep_vars)
    done = false
    while !done
        nextvar = findfirst(dep_vars) do val
            # key, val = x.first, x.second
            deps = val[1]
            ddeps = deps ∩ order
            !isempty(ddeps) && all(setdiff(deps, order)) do other
                !haskey(dep_vars, other) || isempty(dep_vars[other][1] ∩ order)
            end
        end
        if isnothing(nextvar)
            done = true
        else
            push!(order, nextvar)
            delete!(dep_vars, nextvar)
        end
    end
    return order
end

function extract_independent_vars(expr::Expr)
    vars = Pair{Symbol, Tuple{Vector{Symbol}, Union{Expr,Symbol}, Expr}}[]
    for ex in expr.args
        if ex isa Symbol
            push!(vars, ex => (Symbol[], :Any, :()))
        elseif ex isa Expr && ex.head===:(::)
            push!(vars, ex.args[1] => (Symbol[], ex.args[2], :()))
        end
    end
    return vars
end

function extract_dependent_vars(expr::Expr)
    vars = Pair{Symbol, Tuple{Vector{Symbol}, Union{Expr,Symbol}, Expr}}[]
    for ex in expr.args
        (!hasproperty(ex, :head) || !(ex.head === :(=))) && continue
        var = extract_var_and_type(ex.args[1])
        call_expr = ex.args[2]
        if !(call_expr isa Expr) || !(call_expr.head === :call)
            throw(ErrorException("malformed expression $(call_expr)"))
        end
        deps = find_variables(call_expr)
        @debug var
        push!(vars, var[1] => (deps, var[2], call_expr))
    end
    return vars
end

extract_var_and_type(x::Symbol) = (x, :Any)
function extract_var_and_type(expr::Expr)
    if expr.head===:(::)
        return (expr.args...,)
    end
    throw(ErrorException("$expr is not a valid field definition"))
end

function find_variables(expr::Expr)
    vars = Symbol[]
    for ex in expr.args[begin+1:end] # args[1]==call
        if ex isa Symbol
            push!(vars, ex)
        elseif ex isa Expr
            append!(vars, find_variables(ex))
        end
    end
    return unique(vars)
end

bare_struct_def(ex) = Expr(ex.head, ex.args[1:2]..., Expr(:block))

function define_setproperty_dep(T, var::Symbol, type, dep_vars)
    field = Val{var}
    if var in keys(dep_vars)
        msg = "cannot set calculated field $var"
        return quote
            function setproperty!(::$T, ::$field, v)
                throw(ErrorException($msg))
            end
        end
    end
    ord = order(dep_vars, var)
    func = quote
        function setproperty!(x::$T, ::$field, v)
            Base.setfield!(x, $(Meta.quot(var)), convert($type, v))
        end 
    end
    func_body = func.args[end].args[end].args
    for var in ord[begin+1:end]
        push!(func_body, :( calculateproperty!(x, $(Meta.quot(var))) ) )
    end
    push!(func_body, :(return v))
    return func
end

function define_calculateproperty(T, var::Symbol, expr, all_vars::Vector{Symbol})
    field = Val{var}
    expr = postwalk(u->u isa Symbol && u in all_vars ? :(x.$u) : u, expr)
    return :(
        @inline function calculateproperty!(x::$T, ::$field)
            Base.setfield!(x, $(Meta.quot(var)), $expr)
        end
    )
end

function strip(ex)
    ex isa Symbol && return ex
    ex.head == :(<:) && return ex.args[1]
end 

macro computed(ex)
    if !ex.args[1]
        throw(ErrorException("struct must be mutable"))
    end
    if !@capture(ex, mutable struct thetype_{thetypeparams__} __ end)
        @debug "Non-parametric type"
        @capture(ex, mutable struct thetype_ __ end)
        thetypeparams = Any[]
    end
    @debug thetype, thetypeparams
    struct_def = bare_struct_def(ex)
    indep_vars = extract_independent_vars(ex.args[3])
    indep_vars_dict = Dict(indep_vars)
    dep_vars = extract_dependent_vars(ex.args[3])
    dep_vars_dict = Dict(dep_vars)
    all_vars = [collect(keys(indep_vars_dict)); collect(keys(dep_vars_dict))]

    struct_def_body = struct_def.args[3].args
    for var in [indep_vars; dep_vars]
        push!(struct_def_body, Expr(:(::), var.first, var.second[2]))
    end

    # Create an incomplete constructor to initialise the independent variables.
    indep_vars_typed = map(indep_vars) do (var, (_,type,_))
        :( $var :: $((type)))
    end
    @debug indep_vars
    @debug "indep_vars_typed" indep_vars_typed     
    new_stub = isempty(thetypeparams) ? :(new($(first.(indep_vars)...))) : :(new{$(strip.(thetypeparams)...)}($(first.(indep_vars)...)))
    inner_constructor = :(
         function $thetype($(indep_vars_typed...)) where {$(thetypeparams...)}
            obj = $new_stub
            Base.Cartesian.@nexprs $(length(indep_vars)) i -> setproperty!(obj, $(Meta.quot.(first.(indep_vars)))[i], $(first.(indep_vars))[i])
            return obj
         end
    )
    push!(struct_def_body, inner_constructor)
  
    @debug thetype, thetypeparams, struct_def, dep_vars, all_vars

    # imports and struct definition
    return_expr = :(import Base: setproperty!; $struct_def)

    for var in dep_vars
        return_expr = :($return_expr;
        $(define_calculateproperty(thetype, var.first, var.second[end], all_vars))
        )
    end
    for var in [indep_vars; dep_vars]
        return_expr = :($return_expr;
        $(define_setproperty_dep(thetype, var.first, var.second[2], dep_vars_dict))
        )
    end

    return_expr = :($return_expr;
        calculateproperty!(x::$thetype, field::Symbol) = calculateproperty!(x, Val(field));
        setproperty!(x::$thetype, field::Symbol, v) = setproperty!(x, Val(field), v);
        nothing
    )
       
    return esc(return_expr)
end

end
