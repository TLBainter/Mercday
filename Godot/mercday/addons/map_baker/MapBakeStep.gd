@tool
class_name MapBakeStep extends RefCounted

#Base contract for one bake step. A subclass sets its fields in _init; a STAGE const fills stage when it stays 0.
#Keys name a Baked/ file, a source file as "src/<file>" or an in-memory product; "dir/*" matches any "dir/" key.

var step_name: StringName = &""
var stage: int = 0
var inputs: PackedStringArray = PackedStringArray()
var outputs: PackedStringArray = PackedStringArray()
var modifies: PackedStringArray = PackedStringArray()
#Inputs that may be absent; a present one still orders the step after its producer.
var optional: PackedStringArray = PackedStringArray()
#True only for the terrain mesher trio, BakeChunkMerge and BakeBudgetCheck.
var run_last: bool = false


#Every key the step reads: inputs, optional inputs and the keys it modifies in place.
func reads() -> PackedStringArray:
	var all: PackedStringArray = inputs.duplicate()
	all.append_array(optional)
	all.append_array(modifies)
	return all


func run(ctx: MapBakeContext) -> bool:
	return ctx.fail("%s does not override run" % step_name)
