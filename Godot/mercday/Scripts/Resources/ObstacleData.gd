class_name ObstacleData extends Resource

@export var obstacle_name: String = ""
@export var size_x: float = 1.0
@export var size_y: float = 1.0
@export var size_z: float = 1.0
var height: float = 0.0  #height in paces; set from Size Z at load
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
@export var immune_to: String = ""
@export var climbable: bool = false
@export_enum("Easy", "Average", "Difficult") var climb_difficulty: String = "Average"
@export var passthrough: bool = false
@export var pt_enter_harm: int = 0
@export var pt_exit_harm: int = 0
@export var pt_harm_type: String = ""
@export var rugged: bool = false  # costs 1 extra Pace to exit this space
@export var growth_pct: int = 0  # 0-90%; each successful roll drops by 25% of current value
@export var is_building: bool = false  # if true, generates a multi-cell building footprint
@export var building_only: bool = false  # generation only: cannot spawn outside a building
@export var ramp: bool = false
@export var is_room: bool = false
@export var room_type: String = ""
@export var covers: bool = true
@export var sight_cover: bool = false  # never blocks a sight ray; grazes only beside the target
@export var moveable: bool = false
@export var drops: Array[String] = []  # weapon names that may drop when this obstacle is destroyed
@export var guaranteed_structures: Array[String] = []
@export var possible_structures: Array[String] = []
@export var possible_scatter: Array[String] = []
@export var preferred_position: String = ""
@export var city_uses: PackedStringArray = PackedStringArray()  #lamp, sidewalk, alley, square
@export var city_only: bool = false  #the row belongs to city maps alone
@export var interactable: bool = false  #a merc may spend the Interact action on this
@export var interaction_result: String = ""  #what Interact does, e.g. "Open/Close"
