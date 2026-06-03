class_name BuildingConfig

## Passed to generate_random() / generate_buildings() to control building generation.
## All fields are optional; unset fields fall back to the normal random pipeline.

# Force every building slot to use this template. null = draw from pool.
var forced_template: ObstacleData = null

# Override the building count for this field. -1 = use MAX_BUILDINGS_BY_DENSITY.
var max_count: int = -1

# Minimum Chebyshev distance between building footprints. 0 = no constraint.
# Not yet enforced in placement logic; reserved for future use.
var min_spacing: int = 0

# If non-empty, only buildings whose obstacle_name is in this list may be placed.
# Not yet enforced; reserved for future use.
var allowed_types: Array[String] = []

# obstacle_names that must not be placed on this field.
# Not yet enforced; reserved for future use.
var excluded_types: Array[String] = []
