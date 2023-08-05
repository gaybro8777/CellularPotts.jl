using OrdinaryDiffEq

function fish_stock!(ds, s, p, t)
    max_population, h = p
    ds[1] = s[1] * (1 - (s[1] / max_population)) - h
end

stock = 400.0
max_population = 500.0
min_threshold = 60.0


prob = ODEProblem(fish_stock!, [stock], (0.0, Inf), [max_population, 0.0])
integrator = init(prob, Tsit5(); advance_to_tstop = true)



# We step 364 days with this call.
step!(integrator, 30.0, true)


# Only allow fishing if stocks are high enough
integrator.p[2] = integrator.u[1] > min_threshold ? rand(300:500) : 0.0
# Notify the integrator that conditions may be altered
u_modified!(integrator, true)
# Then apply our catch modifier
step!(integrator, 1.0, true)
# Store yearly stock in the model for plotting
stockHistory = integrator.u[1]
# And reset for the next year
integrator.p[2] = 0.0
u_modified!(integrator, true)

#############################################

using OrdinaryDiffEq



function cellCycle!(du, u, p, t)
    α₁, α₂, α₃, β₁, β₂, β₃, K₁, K₂, K₃, n₁, n₂, n₃ = p

    CDK1, PIK1, APC = u

    du[1] = dCDK1 = α₁ - β₁ * CDK1 * APC^n₁ / (K₁^n₁ + APC^n₁)
    du[2] = dPIK1 = α₂*(1-PIK1) * CDK1^n₂ / (K₂^n₂ + CDK1^n₂) - β₂ * PIK1
    du[3] = dAPC = α₃*(1-APC) * PIK1^n₃ / (K₃^n₃ + PIK1^n₃) - β₃ * APC

    return nothing
end

u0 = zeros(3)
p = [0.1, 3.0, 3.0,
     3.0, 1.0, 1.0,
     0.5, 0.5, 0.5,
     8.0, 8.0, 8.0]
t0 = (0.0, 25.0)


prob = ODEProblem(cellCycle!, u0, t0, p)

sol = solve(prob, Tsit5())

#############################################

#= 
Some chemical will reside in a somewhat circular boundary.
Diffusion in and out of the boundary is slow compared to free diffusion
Two reactions for this chemical:
    x --> 2x
    x --> ∅ 
=#
using DifferentialEquations, Graphs, Plots, Printf


dims = (30,30)
numberOfSpecies = 1
numberOfNodes = prod(dims) # number of sites
grid = Graphs.grid(dims)

center = LinearIndices(dims)[dims .÷2...]
starting_state = zeros(Int,numberOfSpecies, numberOfNodes)
starting_state[center] = 25

tspan = (0.0, 10.0)
rates = [2.0, 1.0] # x generation is slower so everthing will be removed eventually

prob = DiscreteProblem(starting_state, tspan, rates)

reactstoch = [[1 => 1],[1 => 1]]
netstoch = [[1 => 1],[1 => -1]]
majumps = MassActionJump(rates, reactstoch, netstoch)

hopConstants = ones(numberOfSpecies, numberOfNodes)
#boundary is harder to hop over
hopConstants[gdistances(grid, center) .== 6] .= -1.0


alg = DirectCRDirect()
jump_prob = JumpProblem(prob,
                        alg,
                        majumps;
                        hopping_constants=hopConstants,
                        spatial_system = grid,
                        save_positions=(true, false))

sol = solve(jump_prob, SSAStepper())


#maxium value obtained
maxu = maximum(maximum.(sol.u))

anim = @animate for t in range(tspan..., 300)
    currTime = @sprintf "Time: %.2f" t
    heatmap(
        reshape(sol(t), dims),
        axis=nothing,
       #clims = (0,maxu),
        framestyle = :box,
        title=currTime)
end

gif(anim, "test.gif", fps = 60)



#############################################
#Graph diffusion


#######################
using Graphs, LinearAlgebra, SparseArrays
using CellularPotts
using Plots


const N = 200
const ΔP = zeros(N,N)

cpm = CellPotts(CellSpace(N,N), CellState([:Epithelial],[500],[10]), [AdhesionPenalty([0 30;30 30]),VolumePenalty([5])]);

#Doing this because we're not using DifferentialEquations
P = zeros(N,N)
for i in eachindex(cpm.space.nodeIDs)
    if !iszero(cpm.space.nodeIDs[i])
        P[i] = rand()
    end
end
P0 = copy(P)

heatmap(P0)

#Updates the laplacian 
function ∇²(Δu,u,space)

    Δx² = nv(space) #Grid spacing
    D=1.0 #Diffusion coefficient
    h = D/Δx²

    for vertex in vertices(space)
        if iszero(space.nodeIDs[vertex])
            continue
        end

        for neighbor in neighbors(space, vertex)
            if space.nodeIDs[vertex] == space.nodeIDs[neighbor]
                @inbounds Δu[vertex] += u[neighbor] - u[vertex]
            end
        end
    end
    

    Δu .*= h


    return nothing
end

for i=1:10000
    ∇²(ΔP,P,cpm.space)
    P .+= ΔP
end

heatmap(P)

N = 10

cpm = CellPotts(CellSpace(N,N), CellState([:Epithelial],[10],[1]), [AdhesionPenalty([0 30;30 30]),VolumePenalty([5])]);

P = zeros(N,N)
nodes = findall(isequal(1), cpm.space.nodeIDs[:])
P[nodes] = rand(length(nodes))

P0 = copy(P)

laplaceCell = laplacian_matrix(cpm.space[nodes], dir=:both)/N^2

for i=1:10000
    P[nodes] -= laplaceCell*P[nodes]
end


heatmap(P0)
heatmap(P)


l = laplacian_matrix(cpm.space, dir=:both)
P[:] = l * P0[:]

Δu = zeros(N,N);
∇²(Δu,u,cpm.space)


Pnew = P0 + Δu


#############################################
# Automatic differentiation
#############################################

#Start with simple central difference approximation

# -Fₓ(x) ≈ ∂H/∂σ(x) ⋅ ∂σ(x)/∂x ≈ (1/2h)⋅( H(σ+dₓσ(x)) - H(σ-dₓσ(x)))

#how do you know what direction the neighbor target is facing?

#Ex 3 by 3 gridS
space = reshape(1:9,3,3)
spaceIndex = CartesianIndices(A)

#=
1  4  7
2  5  8
3  6  9
=#

spaceIndex[5] - spaceIndex[8] #CartesianIndex(0, -1)

Tuple(spaceIndex[5] - spaceIndex[8])


#############################################
# Relative penality contributions
#############################################
using CellularPotts, Plots

cpm = CellPotts(
    CellSpace(50, 50),
    CellState(:Epithelial, 300, 1),
    [AdhesionPenalty(fill(30,2,2)), VolumePenalty([5]), PerimeterPenalty([5])]
)

cpm.record = true

for i=1:100
    ModelStep!(cpm)
end



plot(stack(last(cpm.history.penalty, 100))')

for i in eachindex(cpm.penalties)
    display(histogram(stack(cpm.history.penalty)[i,:], title=cpm.penalties[i]))
end


rows, columns = size(cpm.space)

plt = heatmap(
        cpm.space.nodeTypes',
        c = cgrad(:tol_light, rev=true),
        grid=false,
        axis=nothing,
        legend=:none,
        framestyle=:box,
        aspect_ratio=:equal,
        size = (600,600),
        xlims=(0.5, rows+0.5),
        ylims=(0.5, columns+0.5),
        clim=(0,2)
            )

cellborders!(plt, cpm.space)


recordCPM("OnPatrol.gif", cpm;
    property = :nodeTypes, frameskip=10, c=:RdBu_3)