# UIEvents.gd — Comandos globais de interface.
# Regra: apenas controladores de UI emitem estes sinais.
class_name UIEvents
extends Node

# Comando (não é fato): pede a gravação do jogo. Dono único esperado: SaveManager.
#
# ATENÇÃO — este é o contra-exemplo didático da validação: nenhum SaveManager existe, então
# o comando é emitido sem dono e o logger acusa em runtime. É assim que a falha silenciosa
# aparece: sem esse alerta, o botão "Salvar" simplesmente não faria nada, sem erro nenhum.
signal save_requested()
