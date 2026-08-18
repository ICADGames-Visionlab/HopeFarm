# ItemTransactionEvent.gd — Payload imutável de entrada/saída de item no inventário.
# Motivação: encapsular quatro campos em um objeto evita quebrar todos os listeners a cada
# campo novo, e a origem da transação evita que os ouvintes tenham de inferir o contexto.
class_name ItemTransactionEvent
extends RefCounted

var item_id: StringName
var amount: int
# Origem da transação: &"harvest", &"shop", &"quest_reward", &"consume".
var source: StringName
var resulting_total: int


func _init(
	p_item_id: StringName,
	p_amount: int,
	p_source: StringName,
	p_resulting_total: int
) -> void:
	item_id = p_item_id
	amount = p_amount
	source = p_source
	resulting_total = p_resulting_total


# Representação compacta usada pelo log de eventos, no mesmo padrão dos demais payloads.
func _to_string() -> String:
	return "ItemTransactionEvent(item=%s, amount=%d, source=%s, total=%d)" % [
		item_id, amount, source, resulting_total
	]
