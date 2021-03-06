
"""
    greens(mc::DQMC)

Obtain the current equal-time Green's function, i.e. the fermionic expectation
value of `Gᵢⱼ = ⟨cᵢcⱼ^†⟩`. The indices relate to sites and flavors, but the
exact meanign depends on the model. For the attractive Hubbard model
`G[i, j] = ⟨c_{i, ↑} c_{j, ↑}^†⟩ = ⟨c_{i, ↓} c_{j, ↓}^†⟩` due to symmetry.

Internally, `mc.stack.greens` is an effective Green's function. This method
transforms it to the actual Green's function by multiplying hopping matrix
exponentials from left and right.
"""
@bm greens(mc::DQMC) = copy(_greens!(mc))

"""
    greens!(mc::DQMC[; output=mc.stack.greens_temp, input=mc.stack.greens, temp=mc.stack.Ur])

Inplace version of `greens`.
"""
@bm function greens!(mc::DQMC; output=mc.stack.greens_temp, input=mc.stack.greens, temp=mc.stack.Ur)
    _greens!(mc, output, input, temp)
end



# Implementations with and without checkerboards. 
# Note that we use the Trotter decomposition 
# `exp(-Δτ(V + T)) = exp(-0.5 Δτ T) exp(-Δτ V) exp(-0.5 Δτ T)`
# alongside the cyclic property of determinants 
# `1 / det(I + eT eV1 eT ... eT eVN eT) = 1 / det(I * eT eT eV1 ... eT eT eVN)`
# to increase analytic accuracy. When calculating the greens function we need to
# reverse the cyclic permutation, which happens here.

function _greens!(
        mc::DQMC_CBFalse, target::AbstractMatrix = mc.stack.greens_temp, 
        source::AbstractMatrix = mc.stack.greens, temp::AbstractMatrix = mc.stack.Ur
    )
    eThalfminus = mc.stack.hopping_matrix_exp
    eThalfplus = mc.stack.hopping_matrix_exp_inv
    vmul!(temp, source, eThalfminus)
    vmul!(target, eThalfplus, temp)
    return target
end

function _greens!(
        mc::DQMC_CBTrue, target::AbstractMatrix = mc.stack.greens_temp, 
        source::AbstractMatrix = mc.stack.greens, temp::AbstractMatrix = mc.stack.Ur
    )
    chkr_hop_half_minus = mc.stack.chkr_hop_half
    chkr_hop_half_plus = mc.stack.chkr_hop_half_inv
    copyto!(target, source)

    @inbounds @views begin
        for i in reverse(1:mc.stack.n_groups)
            vmul!(temp, target, chkr_hop_half_minus[i])
            copyto!(target, temp)
        end
        for i in reverse(1:mc.stack.n_groups)
            vmul!(temp, chkr_hop_half_plus[i], target)
            copyto!(target, temp)
        end
    end
    return target
end


# Same stuff with a specified time slice.

"""
    greens(mc::DQMC, l::Integer)

Calculates the equal-time greens function at a given slice index `l`, i.e. 
`G_{ij}(l, l) = G_{ij}(l⋅Δτ, l⋅Δτ) = ⟨cᵢ(l⋅Δτ)cⱼ(l⋅Δτ)^†⟩`.

Note: This internally overwrites the stack variables `Ul`, `Dl`, `Tl`, `Ur`, 
`Dr`, `Tr`, `curr_U`, `tmp1` and `tmp2`. All of those can be used as temporary
or output variables here, however keep in mind that other results may be 
invalidated. (I.e. `G = greens!(mc)` would get overwritten.)
"""
@bm greens(mc::DQMC, slice::Integer) = copy(_greens!(mc, slice))

"""
    greens!(mc::DQMC, l::Integer[; output=mc.stack.greens_temp, temp1=mc.stack.tmp1, temp2=mc.stack.tmp2])

Inplace version of `greens!(mc, l)`
"""
@bm function greens!(
        mc::DQMC, slice::Integer; 
        output=mc.stack.greens_temp, temp1 = mc.stack.tmp1, temp2 = mc.stack.tmp2
    ) 
    _greens!(mc, slice, output, temp1, temp2)
end


function _greens!(
        mc::DQMC, slice::Integer, output::AbstractMatrix = mc.stack.greens_temp, 
        temp1::AbstractMatrix = mc.stack.tmp1, temp2::AbstractMatrix = mc.stack.tmp2
    )
    calculate_greens(mc, slice, temp1)
    _greens!(mc, output, temp1, temp2)
end