class_name ObstacleData extends Resource

@export var obstacle_name: String = ""
@export var size_x: float = 1.0
@export var size_y: float = 1.0
@export var size_z: float = 1.0
var size: int:
	get:
		if size_z == 0.0:
			return ceili((size_x + size_y) / 2.0)
		return ceili((size_x + size_y + size_z) / 3.0)
@export var narrow: bool = false  # only ever grants Partial Cover; space can be passed through
@export var thd_min: float = 0.0
@export var thd_max: float = 0.0
@export_enum("Vegetation", "Furniture", "Terrain", "Structure") var obstacle_type: String = "Terrain"
@export var health: int = 1
@export var susceptible_to: String = ""
@export var climbable: bool = false
@export_enum("Easy", "Average", "Difficult") var climb_difficulty: String = "Average"
@export var passthrough: bool = false
@export var pt_enter_harm: int = 0
@export var pt_exit_harm: int = 0
@export var pt_harm_type: String = ""
@export var rugged: bool = false  # costs 1 extra Pace to exit this space
@export var growth_pct: int = 0  # 0-90%; each successful roll drops by 25% of current value
@export var possible_locations: Array[String] = []  # reserved for future location filtering
@export var is_building: bool = false  # if true, generates a multi-cell building footprint
@export var building_only: bool = false  # generation only: cannot spawn outside a building
@export var ramp: bool = false
@export var is_room: bool = false
@export var room_type: String = ""
@export var covers: bool = true
@export var moveable: bool = false
@export var drops: Array[String] = []  # weapon names that may drop when this obstacle is destroyed
@export var guaranteed_structures: Array[String] = []
@export var excluded_structures: Array[String] = []
@export var possible_structures: Array[String] = []
@export var possible_scatter: Array[String] = []
@export var preferred_position: String = ""
