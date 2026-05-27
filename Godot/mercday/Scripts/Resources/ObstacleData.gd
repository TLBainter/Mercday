class_name ObstacleData extends Resource

@export var obstacle_name: String = ""
@export var size: int = 1
@export var narrow: bool = false  # only ever grants Partial Cover; space can be passed through
@export_enum("SQUARE", "RECTANGLE", "L", "T", "BIG_SQUARE") var shape: String = "SQUARE"
@export var height_min: int = 1
@export var height_max: int = 3
@export_enum("Vegetation", "Furniture", "Terrain", "Structure") var obstacle_type: String = "Terrain"
@export var health: int = 1
@export var susceptible_to: String = ""
@export var climbable: bool = false
@export_enum("Easy", "Average", "Difficult") var climb_difficulty: String = "Average"
@export var passthrough: bool = false
@export var passthrough_enter_harm: int = 0
@export var passthrough_exit_harm: int = 0
@export var passthrough_harm_type: String = ""
@export var rugged: bool = false  # costs 1 extra Pace to exit this space
@export var expansion_odds: int = 0  # 0–90%; each successful roll drops by 25% of current value
@export var possible_locations: Array[String] = []  # reserved for future location filtering
@export var is_building: bool = false  # if true, generates a multi-cell building footprint
@export var is_stairs: bool = false
@export var terrain_height_delta_min: float = 0.0  # negative = depression (pit/cliff bottom)
@export var terrain_height_delta_max: float = 0.0
