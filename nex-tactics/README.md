# NexTactics

Protótipo de jogo tático com tabuleiro, cartas e auto-combate, inspirado em TFT, Pokémon e Yu-Gi-Oh!.

## Objetivo Atual
Entregar uma demo jogável com:
- 3 decks pré-prontos
- posicionamento em tabuleiro
- combate automático
- mestre de deck
- criaturas, suportes e vida global

## Stack
- Godot 4
- GDScript
- VSCode
- GitHub
- Google Sheets
- Obsidian
- Krita

## Escopo da Demo
- 1 modo PvE
- 1 tabuleiro fixo
- 3 decks
- 1 loop completo de rodada
- sem editor de deck
- sem multiplayer online

## Primeiro Teste Técnico
- cena mínima: `res://scenes/battle/battle_scene.tscn`
- root da cena: `BattleManager` (sem UI e sem combate)
- filho: `BoardGrid` (gera o grid lógico no `_ready()`)
