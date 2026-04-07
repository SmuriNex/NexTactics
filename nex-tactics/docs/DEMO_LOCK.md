# DEMO LOCK

## Objetivo

Este documento trava oficialmente o recorte da demo do Warcrown para a Fase 0.

A meta atual nao e expandir o projeto. A meta atual e alinhar producao, documentacao e decisoes em volta de uma demo local-first jogavel, legivel e estavel.

## Visao Da Demo

A demo do Warcrown e uma experiencia local-first de auto-battler tatico com:

- tela inicial principal
- 3 decks pre-prontos
- tela DECK como selecao e onboarding
- fase de preparo
- auto-battle
- cartas de suporte
- rounds com vida global
- encerramento claro de partida

O jogador deve conseguir abrir o jogo, entender os decks, escolher um deles e jogar uma partida completa sem depender de sistemas online.

## Loop Canonico

1. abrir a tela inicial
2. entrar em DECK
3. selecionar 1 entre 3 decks
4. voltar para PLAY
5. iniciar a partida local
6. entrar na fase de preparo
7. realizar deploy, reposicionamento, venda e gestao local do tabuleiro
8. receber oferta de carta de suporte nas rodadas elegiveis
9. assistir ao auto-battle
10. receber o resultado da rodada e o dano a vida global
11. repetir o ciclo ate eliminacao ou vitoria final

## O Que E Nucleo

- tela inicial
- tela DECK
- carregamento de dados dos 3 decks ativos
- fase de preparo
- economia em ouro
- cartas de suporte da partida
- auto-battle
- resolucao de rodada
- vida global
- HUD e feedback suficiente para leitura
- estabilidade de ponta a ponta do loop canonico

## O Que E Sistema Secundario

- observer
- visualizacao de outras mesas
- estruturas de live table
- save mais amplo que preferencias basicas
- ferramentas de editor e plugins que nao sustentam o loop principal

## O Que Fica Fora Do Caminho Critico

- multiplayer online como feature de entrega da demo
- backend
- campanha
- meta progressao maior
- editor de deck
- multiplos tabuleiros
- migracao de IA para nova arquitetura
- troca do sistema atual de cartas por outro plugin
- qualquer refactor grande que nao aumente clareza ou estabilidade da demo

## Base Futura Que Deve Ser Preservada

- `LobbyManager`
- `MatchPlayerState`
- `FormationState`
- `ShopState`
- `CombatInstance`
- snapshots de board
- ranking e eliminacao
- observer data
- arquitetura data-driven de decks, unidades, cartas e skills

## Criterios De Pronto Da Demo

- a tela inicial explica e organiza o fluxo de entrada
- a tela DECK permite entender e escolher os 3 decks
- PLAY so avanca quando houver deck escolhido
- o loop principal roda do PREP ao fim da partida sem quebrar
- a identidade dos 3 decks aparece com clareza em texto, HUD e apresentacao
