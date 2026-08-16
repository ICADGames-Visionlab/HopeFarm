@tool
extends RefCounted
class_name MarkdownParser

## Converts Markdown text to BBCode for RichTextLabel rendering.
## Images are replaced with placeholder tags for async loading.
## Returns a Dictionary: { "bbcode": String, "images": Array[Dictionary] }
## Each image entry: { "id": int, "url": String, "type": "local"|"external" }

static func parse(md: String) -> Dictionary:
	var lines := md.split("\n")
	var output := ""
	var in_code_block := false
	var code_block_lang := ""
	var code_block_lines: Array[String] = []
	var in_ordered_list := false
	var in_unordered_list := false
	var images: Array[Dictionary] = []

	for raw_line in lines:
		var line: String = raw_line.rstrip(" \t")

		# --- Code block open/close ---
		if line.begins_with("```"):
			if in_code_block:
				var code_text := "\n".join(code_block_lines)
				code_text = code_text.replace("[", "[lb]")
				output += "[font_size=12][color=#cdd6f4][bgcolor=#1a1f2e]%s[/bgcolor][/color][/font_size]\n" % code_text
				in_code_block = false
				code_block_lang = ""
				code_block_lines.clear()
			else:
				if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
				if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
				in_code_block = true
				code_block_lang = line.substr(3).strip_edges()
			continue

		if in_code_block:
			code_block_lines.append(raw_line)
			continue

		# --- Empty line ---
		if line.strip_edges() == "":
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "\n"
			continue

		# --- Horizontal rule ---
		if line == "---" or line == "***" or line == "___" or line == "- - -" or line == "* * *":
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "[color=#4a5568]─────────────────────────────────────────────────[/color]\n"
			continue

		# --- Headers ---
		if line.begins_with("#### "):
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "[font_size=15][color=#e8c87a][b]%s[/b][/color][/font_size]\n" % _inline(line.substr(5), images)
			continue
		if line.begins_with("### "):
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "[font_size=17][color=#7aa2f7][b]%s[/b][/color][/font_size]\n" % _inline(line.substr(4), images)
			continue
		if line.begins_with("## "):
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "[font_size=21][color=#89dceb][b]%s[/b][/color][/font_size]\n" % _inline(line.substr(3), images)
			continue
		if line.begins_with("# "):
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "[font_size=27][color=#f38ba8][b]%s[/b][/color][/font_size]\n" % _inline(line.substr(2), images)
			continue

		# --- Blockquote ---
		if line.begins_with("> "):
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			output += "[color=#4a5568]▎[/color] [color=#a6adc8][i]%s[/i][/color]\n" % _inline(line.substr(2), images)
			continue

		# --- Unordered list ---
		var ul_match := _ul_match(line)
		if ul_match != "":
			if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false
			if not in_unordered_list: output += "[ul bullet=•]\n"; in_unordered_list = true
			output += _inline(ul_match, images) + "\n"
			continue

		# --- Ordered list ---
		var ol_match := _ol_match(line)
		if ol_match != "":
			if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
			if not in_ordered_list: output += "[ol type=1]\n"; in_ordered_list = true
			output += _inline(ol_match, images) + "\n"
			continue

		# --- Close lists ---
		if in_unordered_list: output += "[/ul]\n"; in_unordered_list = false
		if in_ordered_list: output += "[/ol]\n"; in_ordered_list = false

		# --- Normal paragraph ---
		output += _inline(line, images) + "\n"

	if in_unordered_list: output += "[/ul]\n"
	if in_ordered_list: output += "[/ol]\n"
	if in_code_block:
		var code_text := "\n".join(code_block_lines).replace("[", "[lb]")
		output += "[font_size=12][color=#cdd6f4][bgcolor=#1a1f2e]%s[/bgcolor][/color][/font_size]\n" % code_text

	return { "bbcode": output, "images": images }


static func _inline(text: String, images: Array[Dictionary]) -> String:
	var result := text

	# Images MUST be extracted BEFORE escaping brackets
	var img_regex := RegEx.new()
	img_regex.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
	var img_results := img_regex.search_all(result)
	for i in range(img_results.size() - 1, -1, -1):
		var m := img_results[i]
		var url: String = m.get_string(2)
		var id := images.size()
		var img_type := "external" if (url.begins_with("http://") or url.begins_with("https://")) else "local"
		images.append({ "id": id, "url": url, "type": img_type })
		var placeholder := "IMG_PLACEHOLDER_%d" % id
		result = result.substr(0, m.get_start()) + placeholder + result.substr(m.get_end())

	# NOW escape brackets — placeholders use [[ ]] so they survive this
	result = result.replace("[", "[lb]")

	# Links also before bracket escape would be better, but links use []()
	# so they need to be extracted too — do it here after image extraction
	var link_regex := RegEx.new()
	link_regex.compile(r"\[([^\]]+)\]\(([^)]+)\)")
	var link_results := link_regex.search_all(result)
	for i in range(link_results.size() - 1, -1, -1):
		var m := link_results[i]
		var link_text: String = m.get_string(1)
		var replacement := "[color=#7aa2f7][u]%s[/u][/color]" % link_text
		result = result.substr(0, m.get_start()) + replacement + result.substr(m.get_end())

	# Inline code
	result = _replace_pattern(result, "`([^`]+)`",
		"[font_size=12][color=#a6e3a1][bgcolor=#1e2030] $1 [/bgcolor][/color][/font_size]")

	# Bold+italic
	result = _replace_pattern(result, r"\*\*\*(.+?)\*\*\*", "[b][i]$1[/i][/b]")
	result = _replace_pattern(result, r"___(.+?)___", "[b][i]$1[/i][/b]")

	# Bold
	result = _replace_pattern(result, r"\*\*(.+?)\*\*", "[b]$1[/b]")
	result = _replace_pattern(result, r"__(.+?)__", "[b]$1[/b]")

	# Italic
	result = _replace_pattern(result, r"\*(.+?)\*", "[i]$1[/i]")
	result = _replace_pattern(result, r"(?<!\w)_(.+?)_(?!\w)", "[i]$1[/i]")

	# Strikethrough
	result = _replace_pattern(result, r"~~(.+?)~~", "[s]$1[/s]")

	return result


static func _replace_pattern(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return text
	return regex.sub(text, replacement, true)


static func _ul_match(line: String) -> String:
	var regex := RegEx.new()
	regex.compile(r"^[\*\-\+] (.+)$")
	var result := regex.search(line)
	if result:
		return result.get_string(1)
	return ""


static func _ol_match(line: String) -> String:
	var regex := RegEx.new()
	regex.compile(r"^\d+\. (.+)$")
	var result := regex.search(line)
	if result:
		return result.get_string(1)
	return ""
