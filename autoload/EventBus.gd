# EventBus.gd — Autoload único do projeto para comunicação entre domínios.
# Motivação: centraliza o roteamento de eventos sem virar um God Object, delegando os sinais
# para objetos de domínio separados. O bus não guarda estado e não contém lógica.
#
# Para adicionar um domínio, são duas edições: criar res://events/domains/<Nome>Events.gd com
# "class_name <Nome>Events extends Node" e registrá-lo abaixo, no mesmo formato dos existentes.
# O guia completo está em docs/event_bus.md.
extends Node

# Cada domínio é um Node filho para aparecer na árvore remota do depurador, o que permite
# inspecionar as conexões em runtime com ferramentas como Signal Lens.
var production: ProductionEvents
var inventory: InventoryEvents
var economy: EconomyEvents
var world: WorldEvents
var ui: UIEvents

var _logger: EventBusLogger


func _ready() -> void:
	production = _register_domain(ProductionEvents.new(), &"production") as ProductionEvents
	inventory = _register_domain(InventoryEvents.new(), &"inventory") as InventoryEvents
	economy = _register_domain(EconomyEvents.new(), &"economy") as EconomyEvents
	world = _register_domain(WorldEvents.new(), &"world") as WorldEvents
	ui = _register_domain(UIEvents.new(), &"ui") as UIEvents

	if OS.has_feature("editor") or OS.is_debug_build():
		# [DEBUG] Instrumentação de eventos: não existe em build de release.
		_logger = EventBusLogger.new()
		_logger.name = &"EventBusLogger"
		add_child(_logger)
		_logger.attach_to_bus(self)
		print("[EventBus] - Bus inicializado com %d domínios" % get_domains().size())


# Adiciona um domínio de eventos como filho do bus e devolve a instância.
# Manter os domínios na árvore é intencional: torna as conexões visíveis no depurador remoto.
func _register_domain(domain: Node, domain_name: StringName) -> Node:
	domain.name = domain_name
	add_child(domain)
	return domain


# Devolve todos os domínios registrados, sem a camada de debug.
# Usado pela instrumentação e pelas ferramentas de verificação para varrer os sinais existentes.
func get_domains() -> Array[Node]:
	var domains: Array[Node] = []
	for child: Node in get_children():
		if child is not EventBusLogger:
			domains.append(child)
	return domains


# Devolve a instrumentação ativa, ou null em build de release.
# Usado pelo overlay de debug e por ferramentas que inspecionam contadores de emissão.
func get_logger() -> EventBusLogger:
	return _logger
