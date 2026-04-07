# Warcrown

Warcrown e um auto-battler tatico em Godot 4.6 com tabuleiro, fase de preparo, cartas de suporte, progressao do Mestre e combate automatico.

O projeto entra nesta fase como uma demo local-first. O foco atual e entregar uma experiencia jogavel, legivel e estavel com 3 decks pre-prontos, tela inicial clara, tela DECK como onboarding e partida completa de ponta a ponta.

## Estado Atual

- engine: Godot 4.6
- cena inicial atual: `res://scenes/ui/start_screen.tscn`
- decks ativos da demo: 3
- fluxo principal atual: start -> deck -> play -> prep -> auto-battle -> resultado de rodada -> proxima rodada
- economia atual: ouro
- vida global atual: 100

## Escopo Oficial

- verdade oficial da demo: `docs/DEMO_LOCK.md`
- recorte de escopo: `docs/demo_scope.md`
- regras atuais de batalha: `docs/battle_rules.md`
- leitura estrutural do projeto: `docs/CRITICAL_PATH_MAP.md`

## Demo Atual

A demo atual deve ser tratada como:

- local-first
- single-player contra o campo local controlado pelo projeto
- tela inicial com PLAY / DECK / MENU
- tela DECK como selecao e onboarding
- 3 decks pre-prontos
- fase de preparo com posicionamento e gestao basica
- auto-battle
- cartas de suporte periodicas
- rounds com dano a vida global
- foco em clareza, estabilidade e legibilidade

## Identidade Atual Dos Decks

- Rei: humanos, reino, ordem, comando
- Necromante: mortos-vivos, ogros corrompidos e necromancia
- Dama do Lago: fadas, elfos, magia, protecao e natureza

## Fora Do Corte Inicial

- editor de deck
- multiplayer online como feature de entrega da demo
- backend
- meta progressao maior
- campanha
- multiplos tabuleiros

## Diretriz Estrutural

O projeto nao deve ser tratado como offline para sempre. Estruturas como lobby, observer, snapshots, ranking, estado de match e simulacao de mesas podem permanecer como base futura para online, desde que nao atrapalhem o caminho critico da demo local-first.

## Nota Tecnica

Alguns nomes tecnicos e paths antigos ainda podem usar `NexTactics` ou `deck_select_screen` por seguranca nesta fase. A identidade visivel do jogo, no entanto, passa a ser `Warcrown`.
