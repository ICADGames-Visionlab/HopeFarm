# EconomyEvents.gd — Eventos do domínio de economia.
# Regra: apenas a Wallet emite estes sinais; qualquer sistema pode ouvir.
class_name EconomyEvents
extends Node

# Emitido a cada mudança no ouro do jogador, com o valor novo e o delta aplicado.
# É o padrão de "mudança de valor": o delta acompanha o total porque vários ouvintes
# precisam da variação, não do acumulado.
# Emissor: Wallet. Ouvinte: HUDController.
signal gold_changed(new_value: int, delta: int)
