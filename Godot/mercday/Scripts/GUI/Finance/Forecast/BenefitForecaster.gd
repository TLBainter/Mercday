class_name BenefitForecaster
extends ExpenseForecaster
#Benefits paid to mercs on top of their wages: the per-contract bonuses, grouped by ledger reason. With no
#history it forecasts nothing.


func reasons() -> Array[String]:
	var out: Array[String] = [GameState.REASON_BONUS]
	out.append_array(backpay_reasons())
	return out


#Hook for backpay: the ledger reasons it will be charged under once it is paid out.
func backpay_reasons() -> Array[String]:
	return []


func group_of(row: TransactionData) -> String:
	return row.reason
