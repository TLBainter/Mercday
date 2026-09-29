class_name NotificationSortPanel extends NotificationFilterPanel

#The "Sort by" popup: the filter popup's box with the two sort orders as its options.

const SORT_URGENCY_LABEL: String = "Urgency"
const SORT_RECENCY_LABEL: String = "Recency"
const SORT_LABELS: Array[String] = [SORT_URGENCY_LABEL, SORT_RECENCY_LABEL]


#The NotificationCenter sort key behind an option label.
static func key_for(label: String) -> StringName:
	return StringName(label.to_lower())


#The option label of a NotificationCenter sort key.
static func label_for(key: StringName) -> String:
	if key == NotificationCenter.SORT_RECENCY:
		return SORT_RECENCY_LABEL
	return SORT_URGENCY_LABEL
