# ProductionEvents.gd — Eventos de qualquer coisa que o jogador põe para produzir e depois coleta.
# É deliberadamente neutro quanto ao conceito: serve para plantação, criação, extração, fabricação
# ou pesca.
#
# Vocabulário: uma FONTE (source) produz um PRODUTO (product) ao longo de um número de dias.
# Regra: apenas sistemas de produção emitem estes sinais; qualquer sistema pode ouvir.
class_name ProductionEvents
extends Node

# Emitido quando o jogador coleta o produto de uma fonte.
# É o exemplo de fan-out do projeto: dois domínios diferentes reagem ao mesmo fato sem se
# conhecerem, e o payload vai em objeto porque são seis campos.
# Emissor: ProductionSource. Ouvintes: InventorySystem, QuestSystem.
signal production_collected(event: ProductionCollectedEvent)
