# Critical Path Map

## Objetivo

Este documento mapeia o caminho critico real da demo do Warcrown e separa:

- fluxo principal da demo
- fluxo auxiliar
- base futura para online
- misturas atuais que merecem refactor futuro

Ele complementa `docs/DEMO_LOCK.md`.

## Fluxo Principal Da Demo

1. entrada
- `project.godot`
- `scenes/ui/start_screen.tscn`
- `scripts/ui/start_screen.gd`

2. tela DECK
- `scenes/ui/deck_select_screen.tscn`
- `scripts/ui/deck_select_screen.gd`

3. escolha de deck
- `scripts/ui/deck_select_screen.gd`
- `autoload/game_data.gd`

4. entrada na partida
- `scenes/battle/battle_scene.tscn`
- `scripts/battle/battle_manager.gd`

5. setup da match local
- `scripts/battle/battle_manager.gd`
- `scripts/match/lobby_manager.gd`
- `scripts/match/round_flow_state.gd`

6. preparacao
- `scripts/battle/battle_manager.gd`
- `scenes/ui/deploy_bar.tscn`
- `scripts/board/board_system.gd`
- `scripts/board/board_grid.gd`

7. loja e supports
- `scripts/battle/battle_manager.gd`
- `scripts/match/lobby_manager.gd`
- `scripts/ui/battle_hud.gd`

8. batalha local
- `scripts/battle/battle_manager.gd`

9. resultado da rodada
- `scripts/battle/battle_manager.gd`
- `scripts/match/lobby_manager.gd`

10. proxima rodada
- `scripts/battle/battle_manager.gd`

11. tela final
- `scripts/battle/battle_manager.gd`
- `scripts/ui/battle_hud.gd`

## Ownership Canonico

### StartScreen

Dono de:

- identidade de entrada da demo
- gating de PLAY por deck selecionado
- acesso a DECK
- placeholder visual de MENU

Nao deve virar:

- tela de match
- tela de opcoes completa nesta fase

### DeckSelectScreen

Dono de:

- selecao detalhada dos 3 decks
- onboarding curto de deck e loop
- confirmacao do deck atual

Nao deve virar:

- controller de match
- ponto de entrada direto da batalha

### BattleManager

Dono atual do caminho critico da demo.

Dono de:

- setup da partida local
- preparo local
- uso local de supports
- progressao local do Mestre
- combate local
- resolucao local da rodada
- transicao para proxima rodada
- encerramento local da partida

Usa apoio interno de:

- `BattlePrepHelper` para estado, payload e interacao leve de `prep`
- `MatchPlayerState` + `MasterProgressionState` para XP, nivel, capacidade e promocao por jogador
- `BattleHUD` + `MasterPromotionToken` para a UX local da ficha arrastavel de promocao

### LobbyManager

Suporte de match state da demo e base futura para online.

### CombatInstance

Base futura para observer, live tables e visualizacao paralela de mesas.

## Nota Tecnica

O path tecnico `deck_select_screen` foi preservado nesta fase por seguranca, mas seu papel agora e o de tela DECK, nao mais o de entrada direta da partida.
