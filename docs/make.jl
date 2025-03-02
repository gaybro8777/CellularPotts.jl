using Documenter
using CellularPotts


makedocs(
    sitename = "CellularPotts.jl",
    format = Documenter.HTML(size_threshold=5_000_000), #max size 5mb
    modules = [CellularPotts],
    pages = [
        "Introduction" => "index.md",
        "Examples" => [
            "Hello World" => "ExampleGallery/HelloWorld/HelloWorld.md",
            "Let's Get Moving" => "ExampleGallery/LetsGetMoving/LetsGetMoving.md",
            "On Patrol" => "ExampleGallery/OnPatrol/OnPatrol.md",
            "Bringing ODEs To Life" => "ExampleGallery/BringingODEsToLife/BringingODEsToLife.md",
            "Going 3D" => "ExampleGallery/Going3D/Going3D.md",
            "Diffusion Outside Cells" => "ExampleGallery/DiffusionOutsideCells/DiffusionOutsideCells.md",
            "Diffusion Inside Cells" => "ExampleGallery/DiffusionInsideCells/DiffusionInsideCells.md",
            "Tight Spaces" => "ExampleGallery/TightSpaces/TightSpaces.md",
            "Over Here" => "ExampleGallery/OverHere/OverHere.md",
            "Travel Time" => "ExampleGallery/TravelTime/TravelTime.md"],
            "API.md"]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/RobertGregg/CellularPotts.jl.git"
)
