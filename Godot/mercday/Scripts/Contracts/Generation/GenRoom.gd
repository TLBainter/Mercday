class_name GenRoom
#Roster room of the daily round: the plan's roster cap minus every open posting.


#Draft entries on the board, campaign postings included.
static func open_postings(board: ContractBoard) -> int:
	if board == null:
		return 0
	var count: int = 0
	for item: BoardEntry in board.entries:
		if item.is_open():
			count += 1
	return count


static func room(board: ContractBoard, roster_max: int) -> int:
	return maxi(0, roster_max - open_postings(board))
