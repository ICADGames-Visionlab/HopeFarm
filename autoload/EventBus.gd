# EventBus.gd — Autoload único do projeto para comunicação entre domínios.
# Motivação: centraliza o roteamento de eventos sem virar um God Object, delegando os sinais
# para objetos de domínio separados. O bus não guarda estado e não contém lógica.
#
# ESTADO ATUAL: nenhum domínio registrado. Domínios nascem junto com o sistema que produz os
# fatos — criar eventos antes disso seria adivinhar features.
#
# Para adicionar um domínio, são duas edições:
#   1. crie res://events/domains/<Nome>Events.gd com "class_name <Nome>Events extends Node",
#      contendo apenas sinais tipados e comentados;
#   2. declare a variável tipada abaixo e registre-a em _ready(), no formato:
#
#          var inventory: InventoryEvents
#
#          func _ready() -> void:
#              inventory = _register_domain(InventoryEvents.new(), &"inventory") as InventoryEvents
#
# A partir daí o acesso é EventBus.inventory.<evento>, e a instrumentação encontra o domínio
# sozinha. O guia completo está em docs/event_bus.md.
extends Node

var _logger: EventBusLogger


func _ready() -> void:
	# Os domínios são registrados aqui, antes da instrumentação, para que o logger os encontre.

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
