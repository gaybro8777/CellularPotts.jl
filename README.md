# <img title="CellularPotts.jl" src="docs/src/assets/logo.svg" alt="" width="50"> CellularPotts.jl

[docs-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-url]: https://robertgregg.github.io/CellularPotts.jl/dev/

[![][docs-img]][docs-url] [![codecov](https://codecov.io/gh/RobertGregg/CellularPotts.jl/graph/badge.svg?token=D3GKFH900T)](https://codecov.io/gh/RobertGregg/CellularPotts.jl) [![CI](https://github.com/RobertGregg/CellularPotts.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/RobertGregg/CellularPotts.jl/actions/workflows/CI.yml)

**CellularPotts.jl** is a Julia package designed to simulate behaviors observed in biological cells. These behaviors can be as simple as cell adhesion, or as complex as entire multi-scale models. Users of this package can create 2D and 3D environments with any number of cell types, sizes, and behaviors. Simulations can be recorded and visualized as animations with the help of the Plots.jl package. The goals of this package are to create a flexible coding environment to explore how cell behaviors can coalesce into complex dynamics while still maintaining high performance. Compared to other excellent software for Cellular Potts modeling (e.g., [Morpheus](https://morpheus.gitlab.io/), [Artistoo](https://artistoo.net/), [CompuCell3D](https://compucell3d.org/)), CellularPotts.jl is unique in its approach for a few reasons:

- CellularPotts.jl is written completely in Julia, avoiding the "[two language problem](https://www.nature.com/articles/d41586-019-02310-3)"
  
  - This unites developers and users to one language, simplifies the code base, and makes customization easier.

- The space cells occupy is modeled as a network/graph
  
  - Representing the model as a graph allows access to decades of graph theory research, for example:
    
    - Calculating articulation points to avoid cell fragmentation
    - Using graph partitioning algorithms to simulate cellular division
    - Avoiding cumbersome boundary conditions by simply adding edges that loop around
    - Using graphical Laplacians to simulate diffusion

- CellularPotts.jl can be composed with other Julia packages.
  
  - For example, we can use state-of-the-art differential equation solving techniques from [DifferentialEquations.jl](https://diffeq.sciml.ai/stable/) as opposed to simple Euler methods

## What is Cellular Potts Modeling?

[CPMs](https://en.wikipedia.org/wiki/Cellular_Potts_model) work by defining an integer grid where adjacent sites with the same value comprise an individual cell (Figure 1A). Locations with a value of zero represent empty regions where no cell is present. The model uses a Metropolis–Hastings algorithm to update grid sites to match their neighbors. This process depends on given penalties which can, for example, encourage cells to adhere together or maintain its size (Figure 1B). As these steps are applied to the grid, patterns observed in real cellular systems begin to emerge. The original CPM paper demonstrated how cells can sort themselves given the correct penalties. Over the next 30 years, this modeling paradigm has been updated to include cell migration,  chemotaxis, intracellular forces, and cell signaling.

<img title="ReadMeOverview" src="docs/src/assets/CPMOverview.png">

## Want to Contribute?

Careful attention has been taken to ensure this package is as performant as I can possibly make it, however, if you spot something egregious in the package, feel free to raise an issue or pull request.

Also of note, **this package is still in development and is not currently recommended for general use**. However, still feel free to try it and give suggestions if you're curious. 

## Quick Start

To create a basic Cellular Potts Model, you need to provide 3 pieces of information:

1. What space will the cells occupy?

2. What cells do you want to include in the model?

3. What penalties do you want to add to encourage certain behaviors?

```julia
#Install the package (if needed)
using Pkg; Pkg.add("CellularPotts")

#Load in the package
using CellularPotts

#Create a space (50×50) for cells to exist in
space = CellSpace(50,50; isPeriodic=true, neighborhood=:moore)

#Describe the cells in the model
initialCellState = CellState(
    :Epithelial, #names
    500,         #sizes
    1)           #counts

#Add penalties to the model
penalties = [
    AdhesionPenalty([0 20;
                     20 0]),
    VolumePenalty([5])
    ]

#Create a model object
cpm = CellPotts(space, initialCellState, penalties)

#Record a simulation of the model
recordCPM("ReadMeExample.gif", cpm)
```

<img title="ReadMeEaxmple" src="https://github.com/RobertGregg/CellularPotts.jl/blob/master/docs/src/ExampleGallery/HelloWorld/HelloWorld.gif?raw=true">

## Improvements

- [ ] `CellDivision!()` currently cannot update custom cell state properties

- [ ] Keyword options for cell state (to add cell properties)

- [ ] Use automatic differentiation to calculate [cellular forces](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007459) from the Hamiltonian

- [ ] Create more unit tests for reproducibility

- [ ] Use SVectors to store graph edges? 🤔
  - Only useful for spaces where all nodes are identical (e.g., periodic boundaries)
- [ ] Add more tests and CI badge
