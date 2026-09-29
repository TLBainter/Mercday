class_name TreeIcons
extends RefCounted

#Atlas id for every Customize tree key: category boxes, module blocks and the base plan block.
#Every tree id is mono art, so the caller passes the colour as the tint.
#"contracts" is the tree's contract-limit node and maps to limit_contracts, not to the Metrics tab
#id "contracts". "metricsCat" never reaches a draw because TreeLayout.CAT_ALIAS routes it to
#"insights", but the entry is kept so id_of never returns "" for a live key.
#The atlas id base_plan is left unused: the base block is the My Mercday logo drawn grayscale
#plus tint.

const IDS: Dictionary = {
	"promoCat": "promo_cat",
	"promotions": "promo_node",
	"promomethods": "promo_methods",
	"longpromos": "long_promos",
	"marketing": "marketing",
	"guildpromo": "guild_promo",
	"metricsCat": "chart_arrow",
	"contractmetrics": "contract_metrics",
	"mercmetrics": "merc_metrics",
	"coaching": "coaching",
	"pip": "pip_plan",
	"combatpip": "combat_pip",
	"skillpip": "skill_pip",
	"magicpip": "magic_pip",
	"peer": "peer",
	"customer": "customer",
	"fastmetrics": "chart_arrow",
	"criminal": "criminal",
	"testing": "testing",
	"aptitude": "aptitude",
	"brawn": "brawn",
	"readiness": "readiness",
	"personality": "personality",
	"skilltest": "skill_test",
	"education": "education",
	"contracts": "limit_contracts",
	"limits": "limits",
	"base": "mercday",
	"seats": "seats",
	"insights": "insights",
	"bazaarCat": "bazaar_cat",
	"bazaar": "bazaar_node",
	"betteritems": "better_items",
	"fasteritems": "faster_items",
	"lessLegal": "less_legal",
	"legalCat": "legal_cat",
	"opspermit": "ops_permit",
	"teleport": "teleport",
	"representation": "representation",
	"counsel": "counsel",
	"whoknows": "who_knows",
	"oddjobs": "odd_jobs",
	"discrim": "discrimination",
	"background": "magnifier",
	"survey": "survey",
}


static func id_of(key: String) -> String:
	return String(IDS.get(key, ""))
