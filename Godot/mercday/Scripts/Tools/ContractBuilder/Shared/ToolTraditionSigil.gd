@tool
class_name ToolTraditionSigil extends TraditionSigil

#TraditionSigil for editor tools, made in code by make(); _init primes the Icons tables its _draw reads.
#The sigil reaches no autoload; once ready, TraditionSigil._refresh sizes it to Icons.CELL times pixel_scale.


static func make(tradition_name: String) -> ToolTraditionSigil:
	var sigil: ToolTraditionSigil = ToolTraditionSigil.new()
	sigil.tradition = tradition_name
	sigil.pixel_scale = 2
	return sigil


func _init() -> void:
	ToolIcons.prime()
