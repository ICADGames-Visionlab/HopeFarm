# WorldEvents.gd — Eventos do domínio de mundo (tempo e ciclo dia/noite).
# Regra: apenas o WorldClock emite estes sinais; qualquer sistema pode ouvir.
class_name WorldEvents
extends Node

# Emitido no instante em que um novo dia de jogo começa, com o número do dia já atualizado.
# É o evento de maior fan-out da validação: três sistemas de domínios diferentes reagem a ele.
# Emissor: WorldClock. Ouvintes: ProductionSource, QuestSystem, HUDController.
signal day_started(day: int)

# Emitido quando o dia passa do limiar de anoitecer. Não repete dentro do mesmo dia.
# Exemplo de evento sem payload: o fato basta, não há dado a transportar.
# Emissor: WorldClock. Ouvinte: AudioDirector.
signal night_started()
