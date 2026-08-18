# InventoryEvents.gd — Eventos do domínio de inventário.
# Regra: apenas o InventorySystem emite estes sinais; qualquer sistema pode ouvir.
class_name InventoryEvents
extends Node

# Emitido após um item entrar no inventário, com o total resultante já consolidado.
# Fecha a única cadeia de dois saltos da validação: production_collected → item_added.
# Emissor: InventorySystem. Ouvinte: HUDController.
signal item_added(event: ItemTransactionEvent)
