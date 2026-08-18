# HopeFarm

Jogo em **Godot 4.7** (GL Compatibility, GDScript).

## Arquitetura

A comunicação entre sistemas usa um **Event Bus** — um único Autoload (`EventBus`) que expõe domínios de
eventos e apenas transporta fatos, sem guardar estado nem conter lógica.

> Esta branch (`2.1(DEBUG)-teste-event-bus`) inclui uma **camada de validação**: domínios de exemplo,
> sistemas mínimos, uma cena de playground e um verificador de fluxo. Ela serve para exercitar o bus e não
> é design de gameplay.

| Documento | O que contém |
| --- | --- |
| **[`docs/event_bus.md`](docs/event_bus.md)** | Documentação da feature: o que é, por que é assim, como criar um domínio, ouvir, emitir, depurar e verificar |
| [`docs/event_catalog.md`](docs/event_catalog.md) | Catálogo dos eventos: payload, emissor, ouvintes esperados e frequência |

## Verificação local

Rodar antes de abrir PR, a partir da raiz do projeto:

```bash
godot --headless --path . --script res://tools/CheckEventBudgets.gd
```

Confere orçamento de sinais por domínio, tipagem das assinaturas, nomenclatura, imutabilidade dos payloads e
sincronia com o catálogo.

```bash
godot --headless --path . res://tools/SmokeTestEventBus.tscn
```

Exercita o ciclo de produção e o ciclo dia/noite ponta a ponta e confere os efeitos que só podem ter
acontecido através do bus. Ambos saem com código 1 se houver erro.

Para regenerar o catálogo de eventos, abra `tools/GenerateEventCatalog.gd` no editor e rode com
**File > Run** (`Ctrl+Shift+X`).

## Debug

`scenes/dev/EventBusPlayground.tscn` permite iniciar produção, coletar, avançar dias e vender com botões.
**F3** abre o overlay do Event Bus: emissões por frame, eventos mais emitidos, eventos sem nenhum listener
e histórico das últimas emissões.
