class_name ChipGroup extends VBoxContainer

#A captioned grid of SlotChips under its count, with the LockBlock that takes the grid's place while
#the key is unmet. The chips are spawned on ready, so an instance only records how many it holds.

const CHIP_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/SlotChip.tscn")

@export var caption: String = ""
@export var chip_count: int = 6
#The MercLocks key that gates the grid, or "" for a group every plan may read.
@export var lock_key: String = ""

@onready var head: SectionHead = $Head
@onready var grid: GridContainer = $Chips
@onready var lock: LockBlock = $Lock


func _ready() -> void:
	head.caption = caption
	lock.lock_key = lock_key
	for i: int in chip_count:
		var chip: SlotChip = CHIP_SCENE.instantiate() as SlotChip
		chip.name = "Chip%d" % (i + 1)
		chip.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(chip)
	set_filled(0)


#Writes how many of the group's chips hold an entry over how many it has, as "2/6".
func set_filled(filled: int) -> void:
	head.count_text = "%d/%d" % [filled, chip_count]
