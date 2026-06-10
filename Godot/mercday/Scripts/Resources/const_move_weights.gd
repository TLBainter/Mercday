class_name ConstMoveWeights

const MOVE_CLOSE_WEIGHTS: Dictionary = {
	"path_cost":           -1.0,
	"cover_at_dest":        2.0,
	"flanked_on_arrival":  -1.5,
	"route_hazard":         -1.0,
	"height_bonus":          0.5,
	"goal_persistence":      1.0,
	"jump_penalty":         -2.0,
	"ally_goal_conflict":   -1.5,
	"angle_diversity":       1.2,
	"corridor_crowded":     -0.8,
	"pace_block":           -1.2,
}

const MOVE_FAR_WEIGHTS: Dictionary = {
	"enemy_distance":      1.0,
	"cover_count":         1.5,
	"edge_penalty":        -2.0,
	"los_bonus":           1.5,
	"height_bonus":         0.5,
	"last_from_penalty":   -2.0,
	"goal_persistence":     1.5,
	"flanked_on_arrival":  -1.5,
}
