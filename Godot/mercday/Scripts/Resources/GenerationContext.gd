class_name GenerationContext

var team_size_a: int = 4
var team_size_b: int = 4
#Contract Difficulty the map is sized from; 0 leaves the generator to roll its own.
var difficulty: float = 0.0
#Dungeon cell blocks the map must hold; a Rescue asks for 1 so the captive always has a cell.
var min_cell_blocks: int = 0
#Street side the building faces; "" leaves the generator to roll its own.
var building_front: String = ""
#Interior floor height in cells; 0 leaves the generator to roll its own.
var floor_height: int = 0
#City block size tier: Small, Medium, Large or Massive; "" leaves the generator to roll its own.
var city_tier: String = ""
