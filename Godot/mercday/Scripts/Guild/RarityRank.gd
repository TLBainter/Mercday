class_name RarityRank

#Rarity words to the rank the salary formula pays for. Items.tsv writes them lowercase, so the
#lookup trims and lower-cases first; an unknown or blank word ranks 0, the Common rank.
#LevelUpSystem.RARITY_RANK and WeightedTable.TIER_WEIGHTS keep their own scales.

const RANKS: Dictionary = {
	"ordinary": -1,
	"common": 0,
	"uncommon": 1,
	"rare": 2,
	"very rare": 3,
	"legendary": 4,
	"unique": 3,
	"heirloom": 4,
	"artifact": 5,
}


static func rank(text: String) -> int:
	return int(RANKS.get(text.strip_edges().to_lower(), 0))
