
import Random
import PyPlot
import Statistics

import AbstractTrees

using LinearAlgebra

import Colors

#include("../src/PatchMixtureKriging.jl")
import PatchMixtureKriging

#PyPlot.matplotlib["rcParams"][:update](["font.size" => 22, "font.family" => "serif"])


include("../examples/helpers/visualization.jl")
include("../examples/helpers/utils.jl")


PyPlot.close("all")

PyPlot.matplotlib["rcParams"][:update](["font.size" => 22, "font.family" => "serif"])


Random.seed!(25)

fig_num = 1

#θ = PatchMixtureKriging.Spline34KernelType(0.1) # larger value is narrower bandwidth.
θ = PatchMixtureKriging.Spline34KernelType(1/15)
D = 2
σ² = 1e-5
N = 850
#N = 35000

# if 0 and 1 are included, we have posdef error, or rank = N - 2.
#x_range = LinRange(-1, 2, N)



# define the oracle.
A = [1.0 0.4; 0.4 1.0] .* 0.1
#offset = [1; 4]
offset = zeros(2)
#f = xx->sinc((norm(xx)/3.2)^2)*(norm(xx)/4)^3
f = xx->sinc((dot((xx-offset),A*(xx-offset))/3.2)^2)*(norm(xx)/4)^3

#### visualize the oracle.
N_array = [100; 200] # number of samples x1, x2.
limit_a = [-5.0; -10.0] # min x1, x2.
limit_b = [5.0; 10.0] # max x1, x2.
x_ranges = collect( LinRange(limit_a[d], limit_b[d], N_array[d]) for d = 1:D )

#X_nD = ranges2collection(x_ranges, Val(D)) # x1 is vertical.

# force x1 to be horizontal instead of vertical.
X_nD = ranges2collection(reverse(x_ranges), Val(D)) # x1 is horizontal.
for i = 1:length(X_nD)
    X_nD[i] = reverse(X_nD[i])
end
f_X_nD = f.(X_nD)

#fig_num = VisualizationTools.visualizemeshgridpcolor(x_ranges,
fig_num = visualizemeshgridpcolorx1horizontal(x_ranges,
f_X_nD, [], "x", fig_num, "Oracle")
# top left is origin, Downwards is positive x2, To the right is positive x1.

# i = 1
# X = X_parts[i]
# x1 = collect( X[n][1] for n = 1:length(X))
# x2 = collect( X[n][2] for n = 1:length(X))
# PyPlot.scatter(x1, x2, label = "$(i)", color = "red")

# i = 2
# X = X_parts[i]
# x1 = collect( X[n][1] for n = 1:length(X))
# x2 = collect( X[n][2] for n = 1:length(X))
# PyPlot.scatter(x1, x2, label = "$(i)", color = "green")

# i = 3
# X = X_parts[i]
# x1 = collect( X[n][1] for n = 1:length(X))
# x2 = collect( X[n][2] for n = 1:length(X))
# PyPlot.scatter(x1, x2, label = "$(i)", color = "blue")

# i = 4
# X = X_parts[i]
# x1 = collect( X[n][1] for n = 1:length(X))
# x2 = collect( X[n][2] for n = 1:length(X))
# PyPlot.scatter(x1, x2, label = "$(i)", color = "yellow")

#@assert 1==4

#### sample from oracle.

#X = collect( randn(D) for n = 1:N )

X = collect( [convertcompactdomain(rand(), 0.0, 1.0, limit_a[1], limit_b[1]);
convertcompactdomain(rand(), 0.0, 1.0, limit_a[2], limit_b[2])] for n = 1:N )
y = f.(X)

X1 = collect( X[n][1] for n = 1:length(X) )
X2 = collect( X[n][2] for n = 1:length(X) )


levels = 3 # 2^(levels-1) leaf nodes. Must be larger than 1.
if N > 10000
    levels = 5
end
root, X_parts, X_parts_inds = PatchMixtureKriging.setuppartition(X, levels)


### visualize tree.
centroid = Statistics.mean( Statistics.mean(X_parts[i]) for i = 1:length(X_parts) )
max_dist = maximum( maximum( norm(X_parts[i][j]-centroid) for j = 1:length(X_parts[i])) for i = 1:length(X_parts) ) * 1.1

y_set = Vector{Vector{Float64}}(undef, 0)
t_set = Vector{Vector{Float64}}(undef, 0)
min_t = -15.0
max_t = 15.0
max_N_t = 5000*3
PatchMixtureKriging.getpartitionlines!(y_set, t_set, root, levels, min_t, max_t, max_N_t, centroid, max_dist)

fig_num, ax = visualize2Dpartition(X_parts, y_set, t_set, fig_num, "levels = $(levels)")
PyPlot.axis("scaled")

ax[:set_xlim]([limit_a[1],limit_b[1]]) # x1 is horizontal (x).
ax[:set_ylim]([limit_a[2],limit_b[2]]) # x2 is vertical (y).

#### RKHS.

# get training set.
ε = 1.5
X_set, X_set_inds, region_list_set,
problematic_inds = PatchMixtureKriging.organizetrainingsets(root, levels, X, ε)

fig_num = visualizesingleregions(X_set, y_set, t_set, fig_num)

N2 = collect( length(X_set[n]) for n = 1:length(X_set) )
N1 = collect( length(X_parts[n]) for n = 1:length(X_parts) )
println("N: X_parts: ", N1)
println("N: X_set:   ", N2)
println()

# set up RKHS.
hps = PatchMixtureKriging.fetchhyperplanes(root)
η = PatchMixtureKriging.MixtureGPType(X_set, hps)

# fit RKHS.
println("Begin fitting, N = $(length(X)):")
Y_set = collect( y[X_set_inds[n]] for n = 1:length(X_set_inds))
@time PatchMixtureKriging.fitmixtureGP!(η, Y_set, θ, σ²)
println()

# query.
Xq = vec(X_nD)

# resize!(Xq, 1)
# Xq[1] = [-0.02; 6.7]
# Xq[1] = [-10.0, -5.0]
# Xq[1] = [-2.58, 9.13]

Yq = Vector{Float64}(undef, 0)
Vq = Vector{Float64}(undef, 0)

# for RBF profile.
radius = 0.3
weight_θ = PatchMixtureKriging.Spline34KernelType(1/radius)
#PatchMixtureKriging.evalkernel(0.9, weight_θ) # cut-off at radius.

println("Begin querying, Nq = $(length(Xq)):")
δ = 1e-5 # allowed border at segmentation boundaries.
debug_vars = PatchMixtureKriging.MixtureGPDebugType(1.0)
@time PatchMixtureKriging.querymixtureGP!(Yq, Vq, Xq, η, root, levels, radius, δ, θ, σ², weight_θ, debug_vars)

q_X_nD = reshape(Yq, size(f_X_nD))
Xq_nD = reshape(Xq, size(f_X_nD))


fig_num = visualizemeshgridpcolorx1horizontal(x_ranges,
q_X_nD, [], "x", fig_num, "The regularization result, predictive mean")


# superimpose with regions.
fig_num = visualizemeshgridpcolorx1horizontal(x_ranges,
q_X_nD, [], "x", fig_num, "")


fig_num, ax = visualize2Dpartition(X_set, y_set, t_set, fig_num, "levels = $(levels)"; new_fig_flag = false)
PyPlot.axis("scaled")
PyPlot.title("The regularization result with segmentation superimposed, mean")

#ax[:set_xlim]([limit_a[1],limit_b[1]]) # x1 is horizontal (x).
#ax[:set_ylim]([limit_a[2],limit_b[2]]) # x2 is vertical (y).


# visualize predictive variance.
v_X_nD = log.(reshape(Vq, size(f_X_nD)))
Xq_nD = reshape(Xq, size(f_X_nD))


fig_num = visualizemeshgridpcolorx1horizontal(x_ranges,
v_X_nD, [], "x", fig_num, "The regularization result, predictive variance")
