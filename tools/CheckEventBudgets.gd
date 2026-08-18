# CheckEventBudgets.gd — Verificação automática das regras de escalabilidade do EventBus.
# Motivação: as regras do Event Bus só sobrevivem ao mês 18 se alguém as checar sem depender de
# memória humana em code review. Este script é essa checagem (ver docs/event_bus.md).
#
# Como usar (na raiz do projeto):
#   godot --headless --path . --script res://tools/CheckEventBudgets.gd
#
# Sai com código 1 se houver qualquer erro; avisos não reprovam.
# A análise é textual de propósito: roda em segundos e não depende de importar o projeto.
extends SceneTree

const DOMAINS_DIR: String = "res://events/domains/"
const PAYLOADS_DIR: String = "res://events/payloads/"
const CATALOG_PATH: String = "res://docs/event_catalog.md"
const MAX_SIGNALS_PER_DOMAIN: int = 20
const MAX_DOMAINS: int = 10
const COMMAND_SUFFIX: String = "_requested"
const SIGNAL_PATTERN: String = "^signal\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\((.*)\\))?\\s*$"

# Tipos proibidos em assinatura de sinal: destroem a tipagem e o contrato.
const FORBIDDEN_PARAM_TYPES: Array = ["Dictionary", "Array", "Variant"]

# Terminações de particípio irregular em inglês: "ed" não cobre item_sold nem player_slept.
# Lista aberta — acrescentar conforme novos verbos aparecerem no catálogo.
const IRREGULAR_PAST_ENDINGS: Array = [
	"sold", "slept", "built", "found", "lost", "won", "made", "sent", "left", "kept", "held",
	"begun", "broken", "chosen", "given", "taken", "written", "hit", "put", "set", "cut"
]

# Nomes que são fato mas não terminam em verbo no passado. A heurística de C5 não consegue
# decidir isso sozinha; manter a lista curta e justificar cada entrada em PR.
const PAST_TENSE_EXCEPTIONS: Array = []

var _errors: PackedStringArray = PackedStringArray()
var _warnings: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	var domains: Array[Dictionary] = _analyze_domains()
	_check_domain_count(domains)
	_check_signal_budget(domains)
	_check_payload_immutability()
	_check_catalog(domains)
	_report(domains)
	quit(1 if not _errors.is_empty() else 0)


# Lê todos os scripts de domínio e devolve a estrutura analisada de cada um.
func _analyze_domains() -> Array[Dictionary]:
	var domains: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(DOMAINS_DIR)
	if dir == null:
		_errors.append("Pasta de domínios não encontrada: %s" % DOMAINS_DIR)
		return domains

	var file_names: PackedStringArray = dir.get_files()
	file_names.sort()
	for file_name: String in file_names:
		if file_name.ends_with(".gd"):
			domains.append(_analyze_domain_file(file_name))
	return domains


# Analisa um único arquivo de domínio: extrai os sinais e aplica as regras por sinal
# (C3, C4, C5, C6 e C8; a lista completa está em docs/event_bus.md).
func _analyze_domain_file(file_name: String) -> Dictionary:
	var path: String = DOMAINS_DIR + file_name
	var domain: String = file_name.trim_suffix(".gd").trim_suffix("Events").to_snake_case()
	var signals: Array[Dictionary] = []
	var regex: RegEx = RegEx.create_from_string(SIGNAL_PATTERN)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")

	for index: int in lines.size():
		var line: String = lines[index].strip_edges()
		var location: String = "%s:%d" % [file_name, index + 1]

		if _is_state_or_logic(line):
			_errors.append("%s — domínio não pode declarar var nem func: %s" % [location, line])
			continue

		var found: RegExMatch = regex.search(line)
		if found == null:
			continue

		var signal_name: String = found.get_string(1)
		signals.append({"name": signal_name, "line": index + 1})
		_check_signal_name(signal_name, location)
		_check_signal_params(signal_name, found.get_string(2), location)
		_check_signal_comment(lines, index, signal_name, location)

	return {"name": domain, "file": file_name, "signals": signals}


# C6 — um arquivo de domínio só pode conter sinais, comentários e a declaração da classe.
# Qualquer var guarda estado no bus e qualquer func coloca lógica nele.
func _is_state_or_logic(line: String) -> bool:
	return line.begins_with("var ") or line.begins_with("@export") or line.begins_with("func ")


# C5 — nome de evento deve ser um fato no passado; a exceção é o sufixo de comando.
func _check_signal_name(signal_name: String, location: String) -> void:
	if signal_name != signal_name.to_snake_case():
		_errors.append("%s — sinal %s não está em snake_case" % [location, signal_name])
	if signal_name.ends_with(COMMAND_SUFFIX) or PAST_TENSE_EXCEPTIONS.has(signal_name):
		return
	if _looks_like_past_tense(signal_name):
		return
	_warnings.append("%s — %s não parece estar no passado; confirmar nomenclatura"
		% [location, signal_name])


# Heurística de tempo verbal: particípio regular termina em "ed"; os irregulares vêm da lista.
# É heurística mesmo, por isso C5 é aviso e não erro — a decisão final é da revisão de PR.
func _looks_like_past_tense(signal_name: String) -> bool:
	if signal_name.ends_with("ed"):
		return true
	for ending: String in IRREGULAR_PAST_ENDINGS:
		if signal_name.ends_with(ending):
			return true
	return false


# C3/C4 — todo parâmetro precisa de tipo explícito, e nenhum pode ser um saco genérico.
func _check_signal_params(signal_name: String, params_text: String, location: String) -> void:
	if params_text.strip_edges().is_empty():
		return
	for param: String in params_text.split(","):
		var declaration: String = param.strip_edges()
		if declaration.is_empty():
			continue
		if not declaration.contains(":"):
			_errors.append("%s — parâmetro '%s' de %s está sem tipo (tipagem forte é obrigatória)"
				% [location, declaration, signal_name])
			continue
		var base_type: String = declaration.split(":")[1].strip_edges().split("[")[0].strip_edges()
		if FORBIDDEN_PARAM_TYPES.has(base_type):
			_errors.append("%s — parâmetro '%s' de %s usa payload genérico %s"
				% [location, declaration, signal_name, base_type])


# C8 — cada sinal precisa de um comentário logo acima dizendo quem emite e quem ouve.
# É esse comentário que sustenta a revisão do catálogo.
func _check_signal_comment(lines: PackedStringArray, signal_index: int, signal_name: String,
		location: String) -> void:
	var index: int = signal_index - 1
	while index >= 0 and lines[index].strip_edges().is_empty():
		index -= 1
	if index < 0 or not lines[index].strip_edges().begins_with("#"):
		_warnings.append("%s — %s está sem comentário de documentação acima" % [location, signal_name])


# C2 — teto de domínios. Estourar significa repensar as fronteiras, não aumentar o teto.
func _check_domain_count(domains: Array[Dictionary]) -> void:
	if domains.size() > MAX_DOMAINS:
		_errors.append("Existem %d domínios; o teto do projeto é %d" % [domains.size(), MAX_DOMAINS])


# C1 — teto de sinais por domínio. Estourar significa dividir o domínio.
func _check_signal_budget(domains: Array[Dictionary]) -> void:
	for domain: Dictionary in domains:
		var count: int = (domain["signals"] as Array).size()
		if count > MAX_SIGNALS_PER_DOMAIN:
			_errors.append("Domínio %s tem %d sinais; o teto do projeto é %d"
				% [domain["name"], count, MAX_SIGNALS_PER_DOMAIN])


# C9 — payload é imutável por convenção: um objeto compartilhado entre listeners
# que o alteram reintroduz acoplamento por estado, que é o pior dos dois mundos.
# GDScript não tem readonly, então a checagem é a ausência de setters públicos.
func _check_payload_immutability() -> void:
	var dir: DirAccess = DirAccess.open(PAYLOADS_DIR)
	if dir == null:
		_errors.append("Pasta de payloads não encontrada: %s" % PAYLOADS_DIR)
		return

	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(PAYLOADS_DIR + file_name).split("\n")
		for index: int in lines.size():
			if lines[index].strip_edges().begins_with("func set_"):
				_errors.append("%s:%d — payload não pode expor setter público (imutabilidade)"
					% [file_name, index + 1])


# C7 — todo sinal do código precisa estar no catálogo, e nenhuma linha pode ter TODO pendente.
func _check_catalog(domains: Array[Dictionary]) -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		_errors.append("Catálogo não encontrado em %s (rodar tools/GenerateEventCatalog.gd)"
			% CATALOG_PATH)
		return

	var catalog: String = FileAccess.get_file_as_string(CATALOG_PATH)
	for line: String in catalog.split("\n"):
		if line.strip_edges().begins_with("| `") and line.contains("TODO"):
			_errors.append("Catálogo com TODO pendente: %s" % line.strip_edges())

	for domain: Dictionary in domains:
		for signal_data: Dictionary in domain["signals"]:
			var entry: String = "| `%s` | %s |" % [signal_data["name"], domain["name"]]
			if not catalog.contains(entry):
				_errors.append("Evento %s.%s não está no catálogo (rodar GenerateEventCatalog)"
					% [domain["name"], signal_data["name"]])


# Imprime o resultado no formato de log do Guideline e o veredito final.
func _report(domains: Array[Dictionary]) -> void:
	var total_signals: int = 0
	for domain: Dictionary in domains:
		total_signals += (domain["signals"] as Array).size()
	print("[EventBus] - Checagem: %d domínios, %d sinais" % [domains.size(), total_signals])
	for domain: Dictionary in domains:
		print("[EventBus] -   %-10s %d sinais" % [domain["name"], (domain["signals"] as Array).size()])

	for warning: String in _warnings:
		print("[EventBus] - AVISO: %s" % warning)
	for error: String in _errors:
		printerr("[EventBus] - ERRO: %s" % error)

	if _errors.is_empty():
		print("[EventBus] - Checagem concluída sem erros (%d avisos)" % _warnings.size())
	else:
		printerr("[EventBus] - Checagem reprovada: %d erros, %d avisos"
			% [_errors.size(), _warnings.size()])
