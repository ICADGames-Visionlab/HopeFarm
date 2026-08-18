# ProductionCollectedEvent.gd — Payload imutável do evento de coleta de produção.
# Motivação: eventos com mais de três dados mudam de assinatura com frequência; encapsular em um
# objeto evita quebrar todos os listeners a cada campo novo.
# Os campos são preenchidos apenas no _init e nunca expostos por métodos set_*.
class_name ProductionCollectedEvent
extends RefCounted

var source_id: int
var product_id: StringName
var amount: int
var quality: int
var world_position: Vector2
var collected_at_day: int


func _init(
	p_source_id: int,
	p_product_id: StringName,
	p_amount: int,
	p_quality: int,
	p_world_position: Vector2,
	p_collected_at_day: int
) -> void:
	source_id = p_source_id
	product_id = p_product_id
	amount = p_amount
	quality = p_quality
	world_position = p_world_position
	collected_at_day = p_collected_at_day


# Representação compacta usada pelo log de eventos. Sem isso o logger imprimiria apenas
# "<RefCounted#...>", inútil para reconstruir a cascata de eventos durante a depuração.
func _to_string() -> String:
	return "ProductionCollectedEvent(source=%d, product=%s, amount=%d, quality=%d, day=%d)" % [
		source_id, product_id, amount, quality, collected_at_day
	]
