class_name BuildingConfig

## Passed to generate_random() / generate_buildings() to control building generation.
## All fields are optional; unset fields fall back to the normal random pipeline.

# Force every building slot to use this template. null = draw from pool.
var forced_template: ObstacleData = null

# Override the building count for this field. -1 = use MAX_BUILDINGS_BY_DENSITY.
var max_count: int = -1

# If non-empty, only buildings whose obstacle_name is in this list may be placed.
#Enforced by BuildingGenerator._filtered_pool.
var allowed_types: Array[String] = []

# obstacle_names that must not be placed on this field.
#Enforced by BuildingGenerator._filtered_pool.
var excluded_types: Array[String] = []
