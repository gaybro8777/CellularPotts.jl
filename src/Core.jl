####################################################
# Penalties
####################################################

"""
    Penalty
An abstract type representing a constraint imposed onto the cellular potts model.

To add a new penalty, a new struct subtyping `Penalty` needs to be defined and the `addPenalty!()` function needs to be extended to include the new penalty.

**Note**: variables associated with a new penalty may need to be offset such that index 0 maps to :Medium, index 1 maps to :Cell1, etc.
"""
abstract type Penalty end

"""
    AdhesionPenalty(J::Matrix{Int})
A concrete type that penalizes neighboring grid locations from different cells.

Requires a symmetric matrix `J` where `J[n,m]` gives the adhesion penality for cells with types n and m. `J` is zero-indexed meaning `J[0,1]` and `J[1,0]` corresponds to the `:Medium` ↔ `:Cell1` adhesion penalty.

**Note**: `J` is automatically transformed to be a zero-indexed offset array.
"""
struct AdhesionPenalty <: Penalty
    J::OffsetMatrix{Int, Matrix{Int}}

    function AdhesionPenalty(J::Matrix{Int})
        issymmetric(J) ? nothing : error("J needs to be symmetric")
        
        return new(offset(J))
    end
end

"""
    VolumePenalty(λᵥ::Vector{Int})
A concrete type that penalizes cells that deviate from their desired volume.

Requires a vector `λᵥ` with n penalties where n is the number of cell types. `λᵥ` is zero-indexed meaning `λᵥ[0]` corresponds to the `:Medium` volume penalty (which is set to zero).

**Note**: `λᵥ` is automatically transformed to be a zero-indexed offset array and does not require the volume penalty for `:Medium`.
"""
struct VolumePenalty <: Penalty
    λᵥ::OffsetVector{Int,Vector{Int}}

    function VolumePenalty(λᵥ::Vector{Int})
        λᵥOff = offset([0; λᵥ])
        return new(λᵥOff)
    end
end

"""
    PerimeterPenalty(λᵥ::Vector{Int})
A concrete type that penalizes cells that deviate from their desired perimeter.

Requires a vector `λₚ` with n penalties where n is the number of cell types. `λₚ` is zero-indexed meaning `λₚ[0]` corresponds to the `:Medium` perimeter penalty (which is set to zero).

**Note**: `λₚ` is automatically transformed to be a zero-indexed offset array and does not require the perimeter penalty for `:Medium`.
"""
mutable struct PerimeterPenalty <: Penalty
    λₚ::OffsetVector{Int,Vector{Int}}
    Δpᵢ::Int
    Δpⱼ::Int

    function PerimeterPenalty(λₚ::Vector{Int}) 
        λₚOff = offset([0; λₚ])
        return new(λₚOff, 0, 0)
    end
end

"""
    MigrationPenalty(maxAct, λ, gridSize)
A concrete type that encourages cells to protude and drag themselves forward.

Two integer parameters control how cells protude:
 - `maxAct`: A maximum activity a grid location can have
 - `λ`: A parameter that controls the strength of this penalty
 - 'gridSize': The size of the space, simply supply size(space)

Increasing `maxAct` will cause grid locations to more likely protrude. Increasing `λ` will cause those protusions to reach farther away. 
"""
mutable struct MigrationPenalty <: Penalty
    maxAct::Int
    λ::OffsetVector{Int,Vector{Int}}
    nodeMemory::SparseMatrixCSC{Int,Int}

    function MigrationPenalty(maxAct::T, λ::Vector{T}, gridSize::NTuple{N,T}) where {T<:Integer, N}
        λOff = offset([0; λ])
        return new(maxAct, λOff, spzeros(T,gridSize))
    end
end


"""
    ChemoTaxisPenalty(λ, Species)
A concrete type that encourages cells to move up or down a concentration gradient.

Two integer parameters control how cells protude:
 - `λ`: A parameter that controls the strength of this penalty
 - `Species`: The concentration profile for a species that should match the size of the cell space

Species concentration profile can be updated dynamically (e.g. by an ODE)

Supplying a positive λ will move cells up the gradient, negative values down the gradient.
"""
mutable struct ChemoTaxisPenalty{T<:AbstractArray} <: Penalty
    λ::OffsetVector{Int,Vector{Int}}
    species::T

    function ChemoTaxisPenalty(λ::Vector{N}, species::T) where {N<:Integer, T<:AbstractArray}
        λOff = offset([0; λ])
        return new{T}(λOff, species)
    end
end

#TODO does adding a parameteric type to penality cause issues?

####################################################
# Variables for Markov Step 
####################################################

mutable struct MHStepInfo{T<:Integer}
    sourceNode::T      #Index of node choosen
    targetNode::T      #Index of node choosen
    sourceNeighborNodes::Vector{T} #Indicies for the neighboring nodes
    targetNeighborNodes::Vector{T} #Indicies for the neighboring nodes
    sourceCellID::T    #ID of sourceNode
    targetCellID::T    #ID of chosen cell target
    stepCounter::T     #Counts the number of ModelSteps performed (1 ModelStep = nv(space) MHStep attempts)
    success::Bool      #Tracks if the MHStep was successful
end 

MHStepInfo() = MHStepInfo(0,0,[0],[0],0,0,0, false)


####################################################
# Logging Function
####################################################

struct Hist{N, T<:Integer}
    space::CellSpace{N,T}
    step::Vector{T}
    idx::Vector{T}
    nodeID::Vector{T}
    nodeType::Vector{T}
end

Hist(space) = Hist(space,Int[],Int[],Int[],Int[])

####################################################
# Structure for the model
####################################################

"""
    CellPotts(space, initialCellState, penalties)
A data container that holds information to run the cellular potts simulation.

Requires three inputs:
 - `space` -- a region where cells can exist, generated using `CellSpace()`.
 - `initialCellState` -- a table where rows are cells and columns are cell properties, generated using `CellTable()`.
 - `penalties` -- a vector of penalties to append to the model.
"""
mutable struct CellPotts{N, T<:Integer, V<:NamedTuple, U}
    initialSpace::CellSpace{N,T}
    space::CellSpace{N,T}
    initialState::CellTable{V}
    state::CellTable{V}
    penalties::Vector{U}
    step::MHStepInfo{T}
    getArticulation::ArticulationUtility
    temperature::Float64
    history::Hist{N,T}
    record::Bool

    function CellPotts(space::CellSpace{N,T}, initialCellState::CellTable{V}, penalties::Vector{P}; ) where {N,T,V,P}

        #See https://github.com/JuliaLang/julia/pull/44131 for why Unions are used
        U = Union{typeof.(penalties)...}

        cpm =  new{N,T,V,U}(
            space,
            space,
            initialCellState,
            initialCellState,
            U[p for p in penalties],
            MHStepInfo(),
            ArticulationUtility(nv(space)),
            20.0,
            Hist(space),
            false)

        #Position the cells in the model
        if :positions ∈ keys(initialCellState)
            positionCells!(cpm)
        else
            positionCellsRandom!(cpm)
        end

        #Now that the cells are added in, reset the initial states/Spaces
        cpm.initialSpace = deepcopy(cpm.space)
        cpm.initialState = deepcopy(cpm.state)

        return cpm
    end
end



####################################################
# Reading and Writing History
####################################################
function updateHist!(cpm::CellPotts, step::Int, idx::Int, nodeID::Int, nodeType::Int)
    
    push!(cpm.history.step, step)
    push!(cpm.history.idx, idx)
    push!(cpm.history.nodeID, nodeID)
    push!(cpm.history.nodeType, nodeType)

    return nothing
end

updateHist!(cpm::CellPotts) = updateHist!(cpm,
cpm.step.stepCounter,
                                          cpm.step.targetNode,
                                          cpm.step.sourceCellID,
                                          cpm.state.typeIDs[cpm.step.sourceCellID])


#Given the history, retieve the space at a given time step
function (cpm::CellPotts)(t)

    cpm.history.space.nodeIDs .= cpm.initialSpace.nodeIDs
    cpm.history.space.nodeTypes .= cpm.initialSpace.nodeTypes
    
    stepMatches = 1:searchsortedlast(cpm.history.step, t)

    cpm.history.space.nodeIDs[cpm.history.idx[stepMatches]] .= cpm.history.nodeID[stepMatches]
    cpm.history.space.nodeTypes[cpm.history.idx[stepMatches]] .= cpm.history.nodeType[stepMatches]

    return cpm.history.space #could also return nothing
end
    
####################################################
# Helper functions for CellPotts
####################################################

"""
    countcells(cpm::CellPotts)
    countcells(df::CellTable)

Count the number of cells in the model 
"""
countcells(cpm::CellPotts) = countcells(cpm.state)

"""
    countcelltypes(cpm::CellPotts)
    countcelltypes(df::CellTable)

Count the number of cell types in the model 
"""
countcelltypes(cpm::CellPotts) = countcelltypes(cpm.state)

arrayids(cpm::CellPotts) = arrayids(cpm.space)
arraytypes(cpm::CellPotts) = arraytypes(cpm.space)

#Given a cellID calculate it's perimeter 
function calcuatePerimeter(cpm::CellPotts, cellID::Int)

    perimeter = 0

    #Loop through all of space and count neighbors
    for (node, id) in enumerate(cpm.space.nodeIDs)
        if id ≠ cellID
            continue
        end

        for neighbor in neighbors(cpm.space, node)
            if cpm.space.nodeIDs[neighbor] ≠ cellID
                perimeter += 1
            end
        end
    end

    return perimeter
end

####################################################
# Override Base.show
####################################################

function show(io::IO, cpm::CellPotts) 
    println(io,"Cell Potts Model:")

    #Grid
    print(io, "Grid: ")
    for (i,dim) in enumerate(cpm.space.gridSize)
        if i < length(cpm.space.gridSize)
            print(io, "$(dim)×")
        else
            println(io, "$(dim)")
        end
    end

    #Cells and types
    cellCounts = countmap(cpm.state.names)
    print(io,"Cell Counts:")
    for (key, value) in cellCounts #remove medium
        if key ≠ :Medium
            print(io," [$(key) → $(value)]")
        end
    end

    if length(cellCounts) > 1
        println(io," [Total → $(length(cpm.state.names)-1)]")
    else
        print(io,"\n")
    end

    print(io,"Model Penalties:")
    for p in Base.uniontypes(eltype(cpm.penalties))
        p = Symbol(p)
        print(io," $(replace(String(p),"Penalty"=>""))")
    end
    print(io,"\n")
    println(io,"Temperature: ", cpm.temperature)
    print(io,"Steps: ", cpm.step.stepCounter)
end