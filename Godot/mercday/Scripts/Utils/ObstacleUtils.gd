class_name ObstacleUtils


static func get_hp(obs_data: ObstacleData) -> int:
	match obs_data.obstacle_type:
		"Vegetation", "Furniture":
			return maxi(2, obs_data.size)
		"Terrain":
			return maxi(4, obs_data.size * 2)
		_:
			return maxi(3, obs_data.size)
