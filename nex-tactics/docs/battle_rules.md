# Regras de Batalha

Este documento descreve as regras atuais usadas pelo projeto. Ele nao e um pitch de sistema futuro; ele registra a verdade operacional da demo neste momento.

## Estrutura Base

- partida em rodadas
- fase de preparo antes do combate
- combate automatico
- resultado da rodada causa dano a vida global
- a partida continua ate eliminacao ou vitoria final

## Regras Atuais Da Demo

- recurso principal: ouro
- ouro inicial de match: 3
- renda base por rodada: 5 a partir das rodadas posteriores a rodada 1
- vida global: 100
- limite de campo: dinamico pelo nivel do mestre, de 4 pecas totais no nivel 1 ate 9 pecas totais no nivel 9
- selecao de cartas de suporte: oferta periodica a cada 3 rodadas
- oferta atual de suporte: ate 2 opcoes, com escolha gratuita de 1 carta

## Progressao Do Mestre

- o mestre vai do nivel 1 ao nivel 11
- a capacidade total do campo inclui o mestre
- o nivel 1 comeca com 4 pecas totais: 3 unidades normais + 1 mestre
- o nivel 9 fecha o board em 9 pecas totais: 8 unidades normais + 1 mestre
- os niveis 10 e 11 continuam relevantes, mas focam em promocao de unidade

### Tabela Atual

| Nivel | XP total | Campo total | Promocao |
| --- | ---: | ---: | --- |
| 1 | 0 | 4 | nao |
| 2 | 3 | 5 | nao |
| 3 | 8 | 5 | sim |
| 4 | 13 | 6 | nao |
| 5 | 18 | 6 | sim |
| 6 | 24 | 7 | nao |
| 7 | 31 | 7 | sim |
| 8 | 39 | 8 | nao |
| 9 | 47 | 9 | nao |
| 10 | 56 | 9 | sim |
| 11 | 66 | 9 | sim |

### XP Atual Do Mestre

- +1 XP base ao fim da rodada
- +1 XP adicional se vencer a rodada
- +1 XP adicional se o mestre terminar a rodada vivo

### Recuperacao Atual

- ativa apos 3 derrotas seguidas
- enquanto ativa, cada nova derrota concede +1 XP extra
- termina na proxima vitoria
- ao vencer, a sequencia de derrotas zera

### Promocao MVP Atual

- quando um marco de promocao e alcancado, o jogador ganha 1 promocao pendente
- no prep local, surge uma ficha do Mestre na HUD
- o jogador arrasta essa ficha ate uma unidade aliada elegivel para aplicar a promocao
- a promocao e fixa por classe
- se o jogador iniciar a batalha com promocao pendente, o sistema tenta aplicar fallback automatico na melhor unidade elegivel em campo

## Dano Pos-Combate Atual

O dano pos-combate atual e calculado em duas etapas:

1. base por rodada
- rodadas 1 e 2: base 2
- rodadas 3 e 4: base 3
- rodadas 5 e 6: base 4
- rodadas 7 e 8: base 5
- rodada 9 em diante: base 6

2. bonus por sobreviventes
- soma a quantidade de sobreviventes do lado vencedor

Observacao:

- no fluxo de lobby atual, o dano final aplicado ao perdedor e limitado a 8

## Estrutura Dos Decks

- 1 mestre por deck
- pool de unidades por deck
- pool de cartas de suporte por deck

## Observacoes Importantes

- a documentacao antiga falava em energia e vida 20; isso nao corresponde mais ao estado atual do codigo
- a documentacao antiga dizia que a demo nao teria loja; o projeto atual ja possui oferta periodica de cartas de suporte
- ajustes de balanceamento ainda podem acontecer, mas qualquer mudanca futura deve atualizar este documento e `docs/DEMO_LOCK.md`
