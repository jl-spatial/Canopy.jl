"""
Basic chemical kinetics.

Types

* [`TempDep`](@ref)
* [`TempDepQ10`](@ref)

Functions

* [`arrhenius`](@ref)
* [`q10_temp_dep`](@ref)
* [`enzyme_temp_dep`](@ref)
* [`enzyme_temp_opt`](@ref)
"""
module ChemKinet

include("../docstring_style.jl")

using Canopy.Constants: R

export TempDep,
    TempDepQ10,
    TempDepArrhenius,
    TempDepEnzyme,
    arrhenius,
    q10_temp_dep,
    enzyme_temp_dep,
    enzyme_temp_opt,
    eval_temp_dep

"""A abstract type for structs of temperature dependence parameters."""
abstract type TempDep end

"""
\$Q_{10}\$ temperature dependence parameters.

# Fields

* `q10`: The \$Q_{10}\$ parameter in [`q10_temp_dep`](@ref), dimensionless.
* `temp_ref`: Reference temperature [K].
* `v_max_ref`: Reaction rate at the reference temperature, arbitrary unit.
"""
struct TempDepQ10
    q10::Number
    temp_ref::Number
    v_max_ref::Number
end

struct TempDepArrhenius
    e_act::Number
    temp_ref::Number
    v_max_ref::Number
end

struct TempDepEnzyme
    delta_G_a::Number
    delta_H_d::Number
    delta_S_d::Number
    temp_ref::Number
    v_max_ref::Number
end

"""
Calculate the ratio of reaction rate at a given temperature (`temp`) to that at
a reference temperature (`temp_ref`) using the Arrhenius function. The
activation energy is given by `e_act`.

```math
\\dfrac{k}{k_\\mathrm{ref}} = \\exp\\left[ -\\dfrac{E_\\mathrm{act}}{R} \\cdot
\\left( \\dfrac{1}{T} - \\dfrac{1}{T_\\mathrm{ref}}\\right) \\right]
```

# Examples

```jldoctest
julia> arrhenius(5e4, 298.15, 283.15)
0.3435224255653669
```
"""
function arrhenius(e_act, temp_ref, temp)
    exp(e_act * (temp - temp_ref) / (R * temp_ref * temp))
end

"""
Calculate the ratio of reaction rate at a given temperature (`temp`) to that at
a reference temperature (`temp_ref`) using an exponential function defined by a
`q10` value.

```math
\\dfrac{k}{k_\\mathrm{ref}} = \\exp\\left( Q_{10} \\cdot
\\dfrac{T - T_\\mathrm{ref}}{10\\ \\mathrm{K}} \\right)
```

# Examples

```jldoctest
julia> q10_temp_dep(2.0, 298.15, 283.15)
0.3535533905932738
```
"""
function q10_temp_dep(q10, temp_ref, temp)
    q10^(0.1 * (temp - temp_ref))
end

"""
A helper function to calculate the enzyme reaction rate at a given temperature
(`temp`) in an _arbitrary unit_.

```math
f(T) = \\dfrac{\\exp\\left(-\\dfrac{\\Delta G_\\mathrm{a}}{R T}\\right)}{
    1 + \\exp\\left(
        -\\dfrac{\\Delta H_\\mathrm{d} - T\\Delta S_\\mathrm{d}}{RT}\\right)}
```

# Arguments

* `delta_G_a`: The standard Gibbs free energy of activation of the active state
  of the enzyme [J mol^-1].
* `delta_H_d`: The standard enthalpy change when the enzyme switches from the
  active to the deactivated state [J mol^-1].
* `delta_S_d`: The standard entropy change when the enzyme switches from the
  active to the deactivated state [J mol^-1 K^-1].
* `temp`: Current temperature [K].

!!! note

    This function is reserved for internal calls. Use
    [`enzyme_temp_dep`](@ref) for calculation.
"""
function f_enzyme_temp_dep(delta_G_a, delta_H_d, delta_S_d, temp)
    exp(-delta_G_a / (R * temp)) /
    (1.0 + exp((delta_S_d - delta_H_d / temp) / R))
end

"""
Calculate the ratio of reaction rate at a given temperature (`temp`) to that at
a reference temperature (`temp_ref`) for an enzyme reaction with a temperature
optimum.

```math
\\dfrac{V_\\mathrm{max}(T)}{V_\\mathrm{max}(T_\\mathrm{ref})} =
\\dfrac{f(T)}{f(T_\\mathrm{ref})} \\text{, where}\\quad f(T) =
\\dfrac{\\exp\\left(-\\dfrac{\\Delta G_\\mathrm{a}}{RT}\\right)}{1 + \\exp
\\left(-\\dfrac{\\Delta H_\\mathrm{d} - T\\Delta S_\\mathrm{d}}{RT}\\right)}
```

# Arguments

* `delta_G_a`: The standard Gibbs free energy of activation of the active state
  of the enzyme [J mol^-1].
* `delta_H_d`: The standard enthalpy change when the enzyme switches from the
  active to the deactivated state [J mol^-1].
* `delta_S_d`: The standard entropy change when the enzyme switches from the
  active to the deactivated state [J mol^-1 K^-1].
* `temp_ref`: Reference temperature [K].
* `temp`: Current temperature [K].

# References

* [JEW42] Johnson, F. H., Eyring, H., and Williams, R. W. (1942). The nature of
  enzyme inhibitions in bacterial luminescence: sulfanilamide, urethane,
  temperature and pressure. *J. Cellul. Comparat. Physiol.*, 20(3), 247--268.
  <https://doi.org/10.1002/jcp.1030200302>.
* [SD77] Sharpe, P. J. H. and DeMichele, D. W. (1977). Reaction kinetics of
  poikilotherm development. *J. Theoret. Biol.*, 64(4), 649--670.
  <https://doi.org/10.1016/0022-5193(77)90265-X>.
* [PED04] Peterson, M. E., Eisenthal, R., Danson, M. J., Spence, A., and
  Daniel, R. M. (2004). A new intrinsic thermal parameter for enzymes reveals
  true temperature optima. *J. Biol. Chem.*, 279(20), 20,717--20,722.
  <https://doi.org/10.1074/jbc.m309143200>.

!!! note

    Interpretations of the thermodynamic parameters in this equation may differ
    in the literature, but the mathematical form remains largely the same.

# Examples

```jldoctest
julia> enzyme_temp_dep(4e4, 2e5, 660.0, 298.15, 283.15)
0.5393220862804745
```

# See also

[`enzyme_temp_opt`](@ref)
"""
function enzyme_temp_dep(delta_G_a, delta_H_d, delta_S_d, temp_ref, temp)
    f_enzyme_temp_dep(delta_G_a, delta_H_d, delta_S_d, temp) /
    f_enzyme_temp_dep(delta_G_a, delta_H_d, delta_S_d, temp_ref)
end

"""
Calculates the temperature optimum of an enzyme reaction [K].

```math
T_\\mathrm{opt} = \\dfrac{\\Delta H_\\mathrm{d}}{
    \\Delta S_\\mathrm{d} +
    R \\ln \\left(\\Delta H_\\mathrm{d} / \\Delta G_\\mathrm{a} - 1 \\right)}
```

# Arguments

* `delta_G_a`: The standard Gibbs free energy of activation of the active state
  of the enzyme [J mol^-1].
* `delta_H_d`: The standard enthalpy change when the enzyme switches from the
  active to the deactivated state [J mol^-1].
* `delta_S_d`: The standard entropy change when the enzyme switches from the
  active to the deactivated state [J mol^-1 K^-1].

# Examples

```jldoctest
julia> enzyme_temp_opt(4e4, 2e5, 660.0)
297.8289937283252
```

# See also

[`enzyme_temp_dep`](@ref)
"""
function enzyme_temp_opt(delta_G_a, delta_H_d, delta_S_d)
    delta_H_d / (delta_S_d + R * log(delta_H_d / delta_G_a - 1.0))
end

function eval_temp_dep(p::TempDepQ10, temp)
    p.v_max_ref * q10_temp_dep(p.q10, p.temp_ref, temp)
end

function eval_temp_dep(p::TempDepArrhenius, temp)
    p.v_max_ref * arrhenius(p.e_act, p.temp_ref, temp)
end

function eval_temp_dep(p::TempDepEnzyme, temp)
    p.v_max_ref *
    enzyme_temp_dep(p.delta_G_a, p.delta_H_d, p.delta_S_d, p.temp_ref, temp)
end

end  # module
