# Catálogo de eventos — EventBus

> **Arquivo parcialmente gerado.** As colunas *Evento*, *Domínio* e *Payload* são
> reescritas por `tools/GenerateEventCatalog.gd` (File > Run no editor). As colunas
> *Emissor(es)*, *Ouvintes esperados* e *Frequência esperada* são mantidas à mão e
> preservadas entre execuções — preencha-as no mesmo PR que adiciona o evento.
>
> Nenhum `TODO` pode chegar em `Development`: `tools/CheckEventBudgets.gd` reprova.

| Evento | Domínio | Payload | Emissor(es) | Ouvintes esperados | Frequência esperada |
| --- | --- | --- | --- | --- | --- |
| `gold_changed` | economy | `new_value: int, delta: int` | Wallet | HUDController | dezenas/dia |
| `item_added` | inventory | `ItemTransactionEvent` | InventorySystem | HUDController | ~1/s (pico de coleta) |
| `production_collected` | production | `ProductionCollectedEvent` | ProductionSource | InventorySystem, QuestSystem | ~1/s (pico de coleta) |
| `save_requested` | ui | — | Playground (botão) | SaveManager — **não existe: contra-exemplo deliberado** | poucas/sessão |
| `day_started` | world | `day: int` | WorldClock | ProductionSource, QuestSystem, HUDController | 1 por dia de jogo |
| `night_started` | world | — | WorldClock | AudioDirector | 1 por dia de jogo |
