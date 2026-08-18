# Event Bus

Documentação da feature: o que é, por que é assim, e como trabalhar com ela.

> **Esta branch (`2.1(DEBUG)-teste-event-bus`) carrega uma camada de validação** — seis eventos, cinco
> sistemas mínimos, uma cena de playground e um verificador de fluxo. Ela existe para exercitar o bus,
> ensinar o padrão e provar que a arquitetura funciona; **não é design de gameplay**. Os domínios reais
> nascem junto com os sistemas reais.

---

## O que é

`EventBus` é um Autoload que **transporta fatos** entre sistemas que não se conhecem. Ele não guarda estado
e não tem lógica: quem publica anuncia o que aconteceu, quem ouve decide o que fazer.

```gdscript
EventBus.<domínio>.<evento>.emit(...)      # publicar
EventBus.<domínio>.<evento>.connect(...)   # ouvir
```

Os eventos não ficam soltos num arquivo único: cada domínio é um `Node` filho do bus, com os sinais do seu
módulo. Isso mantém um só Singleton no projeto e evita o arquivo de 300 sinais.

### Por que assim

Um jogo de escopo médio converge para 15–30 sistemas, e a comunicação entre eles é **um-para-muitos**: um
fato interessa ao inventário, ao HUD, às missões, ao áudio e à telemetria ao mesmo tempo. Com chamadas
diretas, o emissor precisa conhecer os cinco, e cada sistema novo obriga a editar código antigo e estável.

Em troca, o bus cobra indireção: acoplamento vira invisível, e um handler removido não dá crash — a feature
só para de acontecer. Toda regra abaixo existe por causa dessa troca, e ela **só compensa quando o fan-out
é real**. Para relação direta e permanente entre dois objetos, chamada direta continua sendo melhor.

Quatro invariantes sustentam o desenho. PR que violar qualquer uma deve ser reprovado:

1. **O bus não guarda estado.** Nada de `EventBus.player_gold`. Estado vive no sistema dono.
2. **O bus não contém lógica.** Sem `if`, sem regra de negócio, sem traduzir evento em evento.
3. **Eventos são fatos no passado**, não comandos (com a exceção controlada de `*_requested`).
4. **Nenhum listener depende da ordem de execução de outro listener.**

E um dono: **cada evento pertence a exatamente um domínio** — o de quem produz o fato —, e só o dono emite.

## Quando usar (e quando não)

Use o bus se o evento satisfizer **pelo menos duas** condições:

1. **Fan-out ≥ 3** — três ou mais sistemas de domínios diferentes reagem ao mesmo fato.
2. **Fronteira de domínio** — emissor e ouvinte são de módulos diferentes.
3. **Fronteira de ciclo de vida** — vivem em cenas diferentes, ou o ouvinte pode nem existir na hora.

Se nenhuma se aplica, **não use o bus**:

| Situação | Use |
| --- | --- |
| Pai e filho da mesma cena | Chamada direta (para baixo), signal local (para cima) |
| Relação 1:1 permanente | Chamada direta |
| Broadcast para N instâncias iguais (todos os inimigos) | `get_tree().call_group()` |
| Precisa de retorno, ou a ordem importa | Chamada direta |

## Eventos existentes

São **seis** — e essa é a lição principal desta branch: o bus tem exatamente os eventos que alguém
escuta, nem um a mais. Cada um foi mantido porque ilustra uma coisa diferente.

| Evento | Domínio | O que ele ensina |
| --- | --- | --- |
| `production_collected` | `production` | **Fan-out**: dois domínios reagem ao mesmo fato sem se conhecerem. Payload em objeto (6 campos) |
| `day_started` | `world` | Maior fan-out da validação: **três** ouvintes de domínios diferentes. Parâmetro simples tipado |
| `night_started` | `world` | Evento **sem payload**: o fato basta |
| `item_added` | `inventory` | A **cadeia de dois saltos** (`production_collected → item_added`), que é o limite |
| `gold_changed` | `economy` | Padrão de **mudança de valor**: valor novo **e** delta |
| `save_requested` | `ui` | **Comando sem dono**: o contra-exemplo, que dispara o alerta do logger |

Repare no que **não** existe: não há `production_started`, `item_removed` nem `quest_completed`, embora os
sistemas façam essas coisas. Ninguém reage a elas, então o evento não existe. Ele nasce no dia em que
aparecer o primeiro ouvinte — e não antes, porque o custo de remover um evento cresce com o número de
listeners.

Detalhes de cada um (payload, emissor, ouvintes, frequência) em
[`event_catalog.md`](event_catalog.md). **Leia o catálogo antes de criar um evento.**

---

## Criar um domínio

Um domínio agrupa os eventos de um módulo. Ele só deve nascer quando existir um sistema real emitindo os
fatos, com pelo menos 3 eventos previstos — criar eventos antes disso é adivinhar feature, e o custo de
renomear ou remover um evento cresce com o número de listeners.

**1. Crie o arquivo** `res://events/domains/CraftingEvents.gd`. Só sinais, comentários e a declaração da
classe: nenhuma `var`, nenhuma `func` (o checador reprova).

```gdscript
# CraftingEvents.gd — Eventos do domínio de fabricação.
# Regra: apenas a CraftingStation emite estes sinais; qualquer sistema pode ouvir.
class_name CraftingEvents
extends Node

# Emitido quando uma receita entra na fila de fabricação de uma bancada.
# Emissor: CraftingStation. Ouvintes: HUD, Quest, Audio.
signal recipe_queued(station_id: int, recipe_id: StringName)

# Emitido quando a fabricação é recusada (falta insumo, bancada ocupada).
# Emissor: CraftingStation. Ouvintes: HUD (feedback), Audio.
signal recipe_rejected(recipe_id: StringName, reason: StringName)
```

**2. Registre no bus** — duas linhas em `autoload/EventBus.gd`:

```gdscript
var crafting: CraftingEvents


func _ready() -> void:
	crafting = _register_domain(CraftingEvents.new(), &"crafting") as CraftingEvents
	...
```

O `as <Tipo>` não é enfeite: `_register_domain()` devolve `Node`, e GDScript não faz *narrowing* implícito.

**3. Regenere o catálogo:** abra `tools/GenerateEventCatalog.gd` no editor e rode com **File > Run**
(`Ctrl+Shift+X`). Preencha as colunas manuais — `TODO` reprova no checador.

**4. Rode o checador** (comando mais abaixo).

Nada mais precisa ser tocado: a instrumentação varre os domínios sozinha e o overlay passa a mostrar os
eventos novos automaticamente.

## Nomear o evento

**Fato no passado**, em inglês, `snake_case`: `item_added`, `day_started`, `gold_changed`. Nunca uma
instrução — `add_item_to_inventory` está errado, isso é chamada direta disfarçada. E evite amarrar o nome a
um conceito de jogo que ainda pode mudar.

| Elemento | Padrão | Exemplo |
| --- | --- | --- |
| Fato (99% dos casos) | `<substantivo>_<verbo no passado>` | `item_added`, `day_started` |
| Mudança de valor | `<substantivo>_changed`, com valor novo **e** delta | `gold_changed(new_value: int, delta: int)` |
| Comando (exceção) | `<substantivo>_<verbo>_requested` | `save_requested` |
| Classe de domínio | `<Domínio>Events` | `InventoryEvents` |
| Classe de payload | `<Evento em PascalCase>Event` | `ItemTransactionEvent` |

O **comando** é a exceção perigosa: ele espera **exatamente um** handler e falha em silêncio se ninguém
tratar — o bus deixa de ser broadcast e vira despacho anônimo. Comando precisa de dono único documentado no
catálogo, e o logger acusa em runtime se a contagem não for 1. Se aparecerem mais de ~5 comandos no
projeto, falta um serviço dedicado (ex.: um `SceneRouter`), não mais um comando.

## Ouvir um evento

Sempre em `_ready()`, sempre por código (nunca pelo editor), sempre com **método nomeado**:

```gdscript
func _ready() -> void:
	EventBus.inventory.item_added.connect(_on_item_added)


# Atualiza o contador do HUD quando qualquer item entra no inventário.
func _on_item_added(event: ItemTransactionEvent) -> void:
	_refresh_slot(event.item_id, event.resulting_total)
```

- **Precisa do valor atual, não só das mudanças?** Consulte o dono do estado no `_ready()`. O bus só entrega
  o que acontece **depois** que você conectou:

  ```gdscript
  var wallet: Wallet = get_tree().get_first_node_in_group(&"wallet") as Wallet
  _set_gold(wallet.current_gold)                           # valor inicial: do dono
  EventBus.economy.gold_changed.connect(_on_gold_changed)  # mudanças: do bus
  ```

  Quem vai ser consultado assim se registra no grupo em **`_enter_tree()`**, não em `_ready()`: a engine
  propaga `_enter_tree` para toda a árvore antes de qualquer `_ready`, então a consulta nunca depende da
  ordem dos nós na cena.

- **Desconectar:** conexões de método de um `Node` caem sozinhas quando o nó é liberado. Se o ouvinte
  **não** for um `Node` da árvore, desconecte em `_exit_tree()`.
- **Uma vez só?** `connect(callable, CONNECT_ONE_SHOT)` — use em tutorial e inicialização.
- **Seu handler mexe na árvore** (instancia ou libera nós)? `connect(callable, CONNECT_DEFERRED)`.

A entrega é **síncrona por padrão** — mais simples de depurar, stack trace inteiro visível. Não há fila de
eventos, e não deve haver enquanto não aparecer um problema concreto de ordenação ou batching.

## Emitir um evento

```gdscript
# Adiciona itens ao inventário e publica o resultado consolidado.
func add_item(item_id: StringName, amount: int, source: StringName) -> void:
	var total: int = get_amount(item_id) + amount
	_items[item_id] = total
	EventBus.inventory.item_added.emit(ItemTransactionEvent.new(item_id, amount, source, total))
	print("[Inventory] - Item \"%s\" x%d adicionado (total %d)" % [item_id, amount, total])
```

Emita **só eventos do seu próprio domínio**. Quem produz o item não emite `inventory.item_added` — quem
emite é o `InventorySystem`, ao reagir.

Evento emitido no `_ready()` de um emissor não é ouvido por ninguém: os outros sistemas ainda não
conectaram. Se o anúncio inicial for necessário, difira com `emit.call_deferred(...)`.

## Escolher o formato do payload

| Campos | Forma | Exemplo |
| --- | --- | --- |
| Nenhum | `signal night_started()` | O fato basta |
| Até 3 | `signal gold_changed(new_value: int, delta: int)` | Parâmetros tipados |
| 4 ou mais | `signal item_added(event: ItemTransactionEvent)` | Classe de payload em `events/payloads/` |

Classe de payload: `extends RefCounted` (nunca `Resource`, salvo se precisar ser serializado), campos
preenchidos só no `_init()`, **sem setters** (o checador reprova), com `_to_string()` implementado — sem ele
o log imprime `<RefCounted#...>` e fica inútil.

Guarde **IDs, não nós**: `source_id: int`, nunca `source: Node`. O payload é um *snapshot*, e o nó pode não
existir mais quando alguém for ler. Se for inevitável, valide com `is_instance_valid()`.

Tipagem é obrigatória em todo parâmetro. `Dictionary`, `Array` e `Variant` genéricos são proibidos —
destroem o contrato e tornam a busca no projeto inútil.

## Limites

Estourar um limite significa **repensar a fronteira**, não aumentar o teto.

| Métrica | Limite | O que fazer se estourar |
| --- | --- | --- |
| Sinais por domínio | ≤ 20 | Dividir o domínio |
| Domínios | ≤ 10 | Reavaliar as fronteiras |
| Listeners por evento | ≤ 8 | Agregar num controlador de domínio |
| Profundidade de cascata | ≤ 2 | Refatorar para chamada direta |
| Emissões por frame (típico) | ≤ 30 | Agregar em um evento com array |
| Tempo do bus por frame | ≤ 0,2 ms típico / 0,5 ms pico | Investigar fan-out e alocação |
| Eventos órfãos (0 listeners por 2 sprints) | 0 | Remover (`[Remove]`) |

Ordem de grandeza para calibrar: emitir um sinal com um listener custa cerca de 3× uma chamada direta, e são
necessárias ~2300 emissões com callback para consumir 1 ms. O problema nunca é o custo de um evento — é
emitir milhares por frame, e isso é sintoma de estrutura errada, não de performance.

---

## Depurar

**F3** abre o overlay do Event Bus em build de debug: emissões no último frame, eventos mais emitidos,
eventos sem listener e histórico das últimas emissões.

O que os alertas do console significam:

| Mensagem | Provável causa |
| --- | --- |
| `AVISO: x.y emitido sem nenhum listener conectado` | Fiação esquecida, ou evento que ninguém usa mais |
| `ERRO: comando x.y_requested tem N listeners` | Comando precisa de exatamente 1 dono — 0 significa que a ação não acontece, 2+ que acontece em dobro |
| `AVISO: x.y emitido N vezes no frame` | Possível laço de realimentação, ou evento que deveria ser agregado |
| `AVISO: x.y em cascata de profundidade N` | Cadeia longa demais (só aparece com `deep_trace` ligado) |

O logger tem flags exportadas para investigação: `log_every_emission` (loga toda emissão, verboso) e
`deep_trace` (mede profundidade de cascata via `get_stack()`, caro — só em auditoria). Ele existe apenas em
`OS.has_feature("editor") or OS.is_debug_build()`.

Se um evento "não chega": confira nesta ordem — (1) o listener conectou em `_ready()`? (2) o nó está na
árvore? (3) o emissor rodou? O overlay responde as três em segundos.

## Camada de validação (DEBUG)

Existe para exercitar o bus de ponta a ponta. Nenhuma peça dela é design de gameplay.

**`scenes/dev/EventBusPlayground.tscn`** — cena manual com três fontes de produção, relógio de mundo,
inventário, missões, carteira, áudio e HUD. Botões: iniciar produção, coletar, avançar dia, vender e um
`Salvar` que emite um comando **sem dono de propósito**, para você ver o alerta do logger acontecendo.

**`tools/SmokeTestEventBus.tscn`** — verificador headless que monta a mesma fatia em memória, dirige o
fluxo por frames e confere os efeitos que só podem ter acontecido através do bus:

| # | Verificação |
| --- | --- |
| V1 | O início da produção muda o estado das três fontes |
| V2 | Duas viradas de dia concluem a produção |
| V3 | A coleta alimenta o inventário sem que os sistemas se conheçam |
| V4 | A mesma coleta avança a missão de coleta |
| V5 | A missão de dias avança só nas viradas, não no dia inicial |
| V6 | A venda remove do inventário e credita a carteira |
| V7 | Cada coleta gera exatamente um `item_added` (cascata ≤ 2) |

Ele é uma **cena**, não um script de `--script`: scripts de MainLoop são compilados antes do registro dos
Autoloads, e naquele modo o identificador global `EventBus` não existe. Vale para qualquer ferramenta
futura que precise tocar o bus.

## Verificar antes do PR

```bash
godot --headless --path . --script res://tools/CheckEventBudgets.gd
```

```bash
godot --headless --path . res://tools/SmokeTestEventBus.tscn
```

Ambos saem com código 1 em caso de erro. O checador confere:

| # | Checagem | Falha |
| --- | --- | --- |
| C1 | ≤ 20 sinais por domínio | erro |
| C2 | ≤ 10 domínios | erro |
| C3 | Todo parâmetro de sinal tem tipo explícito | erro |
| C4 | Nenhum parâmetro é `Dictionary`, `Array` ou `Variant` | erro |
| C5 | Nome em `snake_case` e no passado (ou sufixo `_requested`) | aviso |
| C6 | Nenhuma `var` ou `func` em arquivo de domínio | erro |
| C7 | Todo sinal está no catálogo, sem `TODO` pendente | erro |
| C8 | Todo sinal tem comentário logo acima | aviso |
| C9 | Nenhum payload expõe setter público | erro |

**O que nenhuma ferramenta pega** — e por isso entra na revisão de PR:

- listener que depende da ordem de conexão de outro listener;
- `disconnect()` faltando em ouvinte que não é `Node` da árvore, ou em conexão por lambda;
- handler que reage ao evento certo com a lógica errada;
- evento novo que não passaria na regra de duas condições;
- domínio criado antes de existir um emissor real.

## Checklist de PR de evento

- [ ] O evento passa na regra de duas condições?
- [ ] Existe um emissor real, ou o domínio está sendo criado por antecipação?
- [ ] Nome no passado, em inglês, `snake_case` (ou `_requested` com dono único documentado)?
- [ ] Todos os parâmetros tipados? Formato de payload adequado ao número de campos?
- [ ] O evento pertence ao domínio de **quem produz** o fato?
- [ ] `docs/event_catalog.md` regenerado e com as colunas manuais preenchidas (sem `TODO`)?
- [ ] Listener conecta em `_ready()`, por código, sem lambda?
- [ ] Print de debug no formato `[Área] - mensagem`?
- [ ] Nenhuma cadeia de mais de 2 saltos introduzida?
- [ ] Nenhum listener depende de outro listener ter rodado antes?
- [ ] Ouvinte que **não** é `Node` da árvore desconecta em `_exit_tree()`?

---

## Armadilhas

**Cadeia longa.** Um evento pode gerar no máximo mais um. `production_collected → item_added` é o limite;
`production_collected → item_added → gold_changed` já seria demais — nesse caso, aplique o efeito por
chamada direta no dono do estado. (É por isso que a carteira não reage a nenhum evento: quem vende
chama `add_gold()` direto.)

**Depender da ordem dos listeners.** Se `A` precisa rodar antes de `B`, os dois são o mesmo sistema, ou `B`
deve reagir a um segundo fato que `A` emite.

**Lambda no connect.** Proibida — não aparece nas ferramentas de inspeção e não desconecta de forma
previsível. Use método nomeado.

**Evento por frame ou por entidade.** 500 entidades não emitem 500 eventos. O sistema processa em laço e
emite um só, agregado (`sources_completed(source_ids: PackedInt32Array)`).

**UI conectada em massa.** Se 12 widgets querem `gold_changed`, conecte **um** controlador de HUD ao bus e
distribua internamente por chamada direta.

**Emitir de domínio alheio.** Cada evento tem um dono. Emitir `inventory.item_added` de fora do
`InventorySystem` é violação de PR.

**Criar o domínio antes do sistema.** Evento sem emissor real é adivinhação de feature.

**Sistema criado depois nunca sabe o estado atual.** HUD vazio até a primeira emissão é o sintoma. Consulte
o dono no `_ready()`; o bus entrega só os deltas.

---

## Arquivos

```
autoload/EventBus.gd              # fachada: registra domínios e sobe a instrumentação
events/domains/                   # um arquivo por domínio
events/payloads/                  # classes de payload
events/debug/EventBusLogger.gd    # instrumentação: contadores, alertas, histórico
events/debug/EventBusOverlay.*    # painel F3
tools/GenerateEventCatalog.gd     # regenera o catálogo (File > Run no editor)
tools/CheckEventBudgets.gd        # checagens C1–C9 (headless)
tools/SmokeTestEventBus.*         # verificador de fluxo (headless)  [DEBUG]
systems/                          # sistemas de exemplo da camada de validação  [DEBUG]
ui/hud/                           # HUD de exemplo  [DEBUG]
scenes/dev/                       # cena de playground  [DEBUG]
localization/strings.csv          # chaves usadas pelo HUD de exemplo  [DEBUG]
docs/event_catalog.md             # catálogo de eventos
```

**Pendências conhecidas:** falta medir (a) se a desconexão automática cobre lambdas e objetos `RefCounted`,
e (b) o custo real de emissão com 1/8/32 listeners no hardware alvo, para calibrar o orçamento de frame.
