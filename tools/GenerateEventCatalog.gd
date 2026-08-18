# GenerateEventCatalog.gd — Regenera docs/event_catalog.md a partir dos domínios do EventBus.
# Motivação: o catálogo só responde "quem escuta isso?" se estiver sempre atualizado; deixá-lo
# manual garante que ele apodrece.
#
# Como usar: abrir este arquivo no editor e rodar com File > Run (Ctrl+Shift+X).
#
# As colunas automáticas (Evento, Domínio, Payload) vêm do código; as colunas manuais
# (Emissor(es), Ouvintes esperados, Frequência esperada) são PRESERVADAS do arquivo existente.
# Evento novo entra com TODO nessas três colunas — e TODO reprova o PR pelo CheckEventBudgets.
extends EditorScript

const DOMAINS_DIR: String = "res://events/domains/"
const CATALOG_PATH: String = "res://docs/event_catalog.md"
const TODO_MARK: String = "TODO"
const MANUAL_COLUMNS: int = 3


func _run() -> void:
	var preserved: Dictionary = _read_existing_rows()
	var rows: Array[Dictionary] = _collect_rows()
	if rows.is_empty():
		push_error("[EventBus] - ERRO: nenhum domínio encontrado em %s" % DOMAINS_DIR)
		return

	var written: int = _write_catalog(rows, preserved)
	_report_removed(rows, preserved)
	print("[EventBus] - Catálogo regenerado com %d eventos em %s" % [written, CATALOG_PATH])


# Varre os scripts de domínio e monta uma linha por sinal declarado.
# Usa o Script diretamente: não instancia nada e não depende do bus estar rodando.
func _collect_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for file_name: String in _list_domain_files():
		var script: GDScript = load(DOMAINS_DIR + file_name) as GDScript
		if script == null:
			push_warning("[EventBus] - AVISO: %s não pôde ser carregado" % file_name)
			continue
		var domain: String = _domain_name_from_file(file_name)
		for signal_data: Dictionary in script.get_script_signal_list():
			rows.append({
				"key": "%s.%s" % [domain, signal_data["name"]],
				"event": String(signal_data["name"]),
				"domain": domain,
				"payload": _format_payload(signal_data["args"]),
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["key"]) < String(b["key"]))
	return rows


# Lista os arquivos .gd da pasta de domínios, ignorando arquivos de importação do editor.
func _list_domain_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(DOMAINS_DIR)
	if dir == null:
		return files
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			files.append(file_name)
	return files


# Converte "ProductionEvents.gd" no nome de domínio usado no bus ("production").
func _domain_name_from_file(file_name: String) -> String:
	return file_name.trim_suffix(".gd").trim_suffix("Events").to_snake_case()


# Descreve o payload do sinal a partir da assinatura: "—" para nível A, a classe do objeto
# para nível C, ou a lista de parâmetros tipados para nível B.
func _format_payload(args: Array) -> String:
	if args.is_empty():
		return "—"
	if args.size() == 1 and int(args[0]["type"]) == TYPE_OBJECT:
		var payload_class: String = String(args[0]["class_name"])
		return "`%s`" % (payload_class if not payload_class.is_empty() else "Object")

	var parts: PackedStringArray = PackedStringArray()
	for arg: Dictionary in args:
		parts.append("%s: %s" % [arg["name"], _type_name(arg)])
	return "`%s`" % ", ".join(parts)


# Nome legível do tipo de um parâmetro de sinal, preferindo o class_name quando existe.
func _type_name(arg: Dictionary) -> String:
	var declared_class: String = String(arg.get("class_name", ""))
	if not declared_class.is_empty():
		return declared_class
	return type_string(int(arg["type"]))


# Lê o catálogo atual e guarda as colunas manuais por chave "domínio.evento".
# É o que impede que a regeneração apague o trabalho de documentação do time.
func _read_existing_rows() -> Dictionary:
	var preserved: Dictionary = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		return preserved

	for line: String in FileAccess.get_file_as_string(CATALOG_PATH).split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.begins_with("| `"):
			continue
		var cells: PackedStringArray = _split_row(stripped)
		if cells.size() < 6:
			continue
		var key: String = "%s.%s" % [cells[1], cells[0].replace("`", "")]
		preserved[key] = [cells[3], cells[4], cells[5]]
	return preserved


# Quebra uma linha de tabela markdown nas células, sem as bordas vazias das pontas.
func _split_row(line: String) -> PackedStringArray:
	var cells: PackedStringArray = PackedStringArray()
	for cell: String in line.split("|"):
		cells.append(cell.strip_edges())
	if cells.size() >= 2:
		cells.remove_at(cells.size() - 1)
		cells.remove_at(0)
	return cells


# Escreve o arquivo final, mantendo as colunas manuais e marcando as pendências com TODO.
func _write_catalog(rows: Array[Dictionary], preserved: Dictionary) -> int:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Catálogo de eventos — EventBus")
	lines.append("")
	lines.append("> **Arquivo parcialmente gerado.** As colunas *Evento*, *Domínio* e *Payload* são")
	lines.append("> reescritas por `tools/GenerateEventCatalog.gd` (File > Run no editor). As colunas")
	lines.append("> *Emissor(es)*, *Ouvintes esperados* e *Frequência esperada* são mantidas à mão e")
	lines.append("> preservadas entre execuções — preencha-as no mesmo PR que adiciona o evento.")
	lines.append(">")
	lines.append("> Nenhum `TODO` pode chegar em `Development`: `tools/CheckEventBudgets.gd` reprova.")
	lines.append("")
	lines.append("| Evento | Domínio | Payload | Emissor(es) | Ouvintes esperados | Frequência esperada |")
	lines.append("| --- | --- | --- | --- | --- | --- |")

	for row: Dictionary in rows:
		var manual: Array = preserved.get(row["key"], [TODO_MARK, TODO_MARK, TODO_MARK])
		lines.append("| `%s` | %s | %s | %s | %s | %s |" % [
			row["event"], row["domain"], row["payload"], manual[0], manual[1], manual[2]
		])
	lines.append("")

	var file: FileAccess = FileAccess.open(CATALOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[EventBus] - ERRO: não foi possível escrever %s" % CATALOG_PATH)
		return 0
	file.store_string("\n".join(lines))
	file.close()
	return rows.size()


# Avisa sobre eventos que sumiram do código mas ainda estavam no catálogo:
# são candidatos a um commit [Remove] e à revisão periódica do catálogo.
func _report_removed(rows: Array[Dictionary], preserved: Dictionary) -> void:
	var current: Dictionary = {}
	for row: Dictionary in rows:
		current[row["key"]] = true
	for key: String in preserved:
		if not current.has(key):
			print("[EventBus] - Evento removido do código e retirado do catálogo: %s" % key)
