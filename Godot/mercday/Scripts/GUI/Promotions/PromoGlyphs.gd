class_name PromoGlyphs

#The icons of the My Promotions window: the five campaign type glyphs and the two tab glyphs.
#Every glyph is a cell of the shared icon sheet, named by the "icon" column of
#CampaignTypeDefs.TYPES for a type and by TAB_JOB_ID and TAB_GUILD_ID for a tab. A concluded card
#asks for the grey variant and dims it with dim_modulate; an active tab is painted by TabButton,
#which is why no tone is built here. Icons caches every baked texture.

const TAB_JOB_ID: String = "job_ads"
const TAB_GUILD_ID: String = "guild_ads"
#The type whose icon stands in for a key no table row carries.
const FALLBACK_KEY: StringName = &"flyers"
#One sheet cell is this many pixels on a side; a scale of N draws it N times as wide.
const ICON_SIDE: int = 16
#The prototype dims a concluded card's icon with grayscale(1) brightness(0.6).
const DIM_BRIGHTNESS: float = 0.6


#The sheet id one campaign type draws; a key no row carries reads the fallback row.
static func type_id(key: StringName) -> String:
	var id: String = String(CampaignTypeDefs.find(key).get("icon", ""))
	if id == "":
		id = String(CampaignTypeDefs.find(FALLBACK_KEY).get("icon", ""))
	return id


static func tab_id(mode: StringName) -> String:
	return TAB_GUILD_ID if mode == &"promo" else TAB_JOB_ID


#One campaign type icon as the sheet draws it, or the grey a concluded card asks for.
static func type_icon(key: StringName, scale: int = 1, dim: bool = false) -> Texture2D:
	return Icons.baked(type_id(key), scale, Icons.MODE_GRAY if dim else Icons.MODE_PLAIN)


#The modulate that carries the dim brightness over the grey variant.
static func dim_modulate(dim: bool) -> Color:
	if dim:
		return Color(DIM_BRIGHTNESS, DIM_BRIGHTNESS, DIM_BRIGHTNESS, 1.0)
	return Color.WHITE
