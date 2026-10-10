class_name GenRecord
#The success rates the round reads from a record: overall, last month and blended.


#A null record reads as an empty one.
static func rates(record: GuildRecord, now: int) -> Dictionary:
	var source: GuildRecord = record if record != null else GuildRecord.new()
	return {
		"overall": source.overall(),
		"recent": source.recent(now),
		"blended": source.blended(now),
	}
