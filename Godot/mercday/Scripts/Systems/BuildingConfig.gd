class_name BuildingConfig

#Passed to generate_random() / generate_buildings() to control building generation.
#All fields are optional; unset fields fall back to the normal random pipeline.

var forced_template: ObstacleData = null

#Override the building count for this field. -1 = use MAX_BUILDINGS_BY_DENSITY.
var max_count: int = -1
