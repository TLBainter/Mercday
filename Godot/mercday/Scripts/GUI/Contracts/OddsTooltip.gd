class_name OddsTooltip extends TooltipPanel

#Hover panel for the difficulty stars of a running posting: the meter and the odds in words.

@onready var meter: SuccessMeter = $Rows/Meter


func set_odds(odds: int) -> void:
	set_text("Success Odds", "%d%% success odds" % odds)
	meter.odds = odds
