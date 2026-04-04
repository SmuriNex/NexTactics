# A-Star Grid Map

Node for managing an AStarGrid2D.

Connects to TileMapLayers and groups of dynamic colliders to automatically build the grid and set solid points.

## Objective

Simplify interfacing with the AStarGrid2D.

I kept re-using this between projects and losing changes between versions, so I wanted to have one copy in a centralized place.

## Installation

1.  Go to the `AssetLib` tab.
2.  Search for "A-Star Grid Map Plugin".
3.  Click on the result to open the plugin details.
4.  Click to Download.
5.  Check that contents are getting installed to `addons/` and there are no conflicts.
6.  Click to Install.
7.  Enable the plugin from the Project Settings > Plugins tab.  

When enabled, the plugin will add the `AStarGridMap2D` node. 

## Usage

Add `AStarGridMap2D` to a scene and give it a region. Plug in a tilemap that should be treated as a wall, or the names of groups that have dynamic colliders, like doors or destructible obstacles.

Call `get_world_path_avoiding_points()` to get a path to a target.
