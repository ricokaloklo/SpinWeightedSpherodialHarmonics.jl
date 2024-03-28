using AbstractTrees
include("binarytree.jl")

# A tree node
struct ct2_st2
    coeff::Float64
    ct2_power::Int
    st2_power::Int
end

function log_factorial(n::Int)
    if n == 0
        return 0
    elseif n < 0
        return -Inf
    else
        return sum(log(k) for k in 1:n)
    end
end

function _log_summation_term_prefactor(s::Int, l::Int, m::Int, r::Int)
    # Note that this does not include the (-1)^(l-r-s) factor
    # Check for negative arguments
    if (l-s-r) < 0 || (l-r+m) < 0 || (r+s-m) < 0
        # The whole thing is just 0
        return -Inf
    end
    
    return begin 
        log_factorial(l-s) -
        log_factorial(l-s-r) - log_factorial(r) +
        log_factorial(l+s) -
        log_factorial(l-r+m) - log_factorial(r+s-m)
    end
end

function _summation_term_prefactors(s::Int, l::Int, m::Int)
    log_prefactors = [_log_summation_term_prefactor(s, l, m, r) for r in 0:l-s]
    max_val, _ = findmax(log_prefactors)

    prefactor_signs = [(l-r-s) % 2 == 0 ? 1 : -1 for r in 0:l-s]
    log_prefactors = log_prefactors .- max_val # Now regularized
    prefactors = prefactor_signs .* exp.(log_prefactors)
    return prefactors, max_val
end

function _nth_derivative_spherical_harmonic(s::Int, l::Int, m::Int, theta_derivative::Int, phi_derivative::Int, theta, phi)
    ct2 = cos(theta/2)
    st2 = sin(theta/2)

    _sum = 0.0
    summation_term_prefactors, log_normalization_const = _summation_term_prefactors(s, l, m)
    for r in 0:l-s
        _rsum = 0.0
        root = BinaryNode(ct2_st2(1, 2*r+s-m, 2*l-2*r-s+m)) # root of the tree
        # building the binary tree
        for j in 1:theta_derivative
            #=
                Each derivative wrt theta will add two terms
                one with
                1/2 beta ct2^{alpha+1} st2^{beta-1}
                and one with
                -1/2 alpha ct2^{alpha-1} st2^{beta+1}
            =#
            # now find the appropriate parent
            # traverse the current tree looking for leaves to add new nodes
            for leaf in Leaves(root)
                leftchild(ct2_st2(leaf.data.coeff * 0.5 * leaf.data.st2_power, leaf.data.ct2_power+1, leaf.data.st2_power-1), leaf)
                rightchild(ct2_st2(leaf.data.coeff * -0.5 * leaf.data.ct2_power, leaf.data.ct2_power-1, leaf.data.st2_power+1), leaf)
            end
        end
        # now traverse the final tree
        for leaf in Leaves(root)
            _rsum += leaf.data.coeff * ct2^(leaf.data.ct2_power) * st2^(leaf.data.st2_power)
        end
        _rsum *= summation_term_prefactors[r+1]
        _sum += _rsum
    end
    exp(log_normalization_const) * _swsh_prefactor(s, l, m) * _sum * cis(m*phi) * (m*1im)^phi_derivative
end

function _swsh_prefactor(s::Int, l::Int, m::Int)
    #=
        This is consistent with the expression in wikipedia,
        as well as BHPerturbationToolkit
    =#

    # Implement explicit expression here
    common_factor = (-1)^m * sqrt((2*l+1)/(4*pi))
    if abs(s) == abs(m)
        return common_factor
    elseif s > m
        delta = s - m # which is a positive integer
        out = 1
        for i in 0:1:delta-1
            j = delta - i
            out *= ((l-m-i)/(l+m+j))
        end
        return common_factor * sqrt(out)
    else
        # in this case s < m
        delta = m - s # which is a positive integer
        out = 1
        for i in 0:1:delta-1
            j = delta - i
            out *= ((l+s+j)/(l-s-i))
        end
        return common_factor * sqrt(out)
    end
end
