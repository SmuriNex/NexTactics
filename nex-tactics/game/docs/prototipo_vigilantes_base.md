# Protótipo Base - Vigilante's

## Conceito do jogo

"Vigilante's" nasce como um jogo focado em progressão narrativa e identidade do herói. A fantasia central é acompanhar um civil exausto da rotina de escritório que decide perseguir o antigo sonho de virar herói, aceitando riscos, consequências sociais e escolhas que podem abrir caminhos diferentes no futuro.

Nesta fase, o objetivo não é construir o jogo completo. A meta é preparar uma base jogável, modular e expansível, isolada em `res://game/`, sem conflitar com a estrutura atual já existente do projeto.

## Objetivo deste protótipo

- Validar um fluxo curto, jogável e fácil de expandir.
- Sustentar a apresentação da vida comum do protagonista, um prólogo e o começo da jornada heroica.
- Preparar espaço para criação básica do personagem: nome civil, nome de herói e gênero.
- Estabelecer a primeira grande ramificação do projeto sem ainda construir todos os sistemas finais.

## Loop inicial imaginado

1. Introdução da vida civil e da rotina comum do protagonista.
2. Prólogo com o evento que empurra a mudança de vida.
3. Criação básica do personagem.
4. Escolha da origem inicial.
5. Entrada em um primeiro hub, treino ou missão curta que valide a direção escolhida.

## Importância da escolha entre laboratório e academia

- A escolha define a primeira bifurcação forte de fantasia, tom e progressão.
- O caminho do laboratório aponta para risco, experimento e possível obtenção de poderes.
- O caminho da academia aponta para disciplina, técnica, preparo físico e identidade de vigilante sem poderes.
- Essa decisão serve como fundação para futuras diferenças de progressão, abordagem de combate, reação social e narrativa.

## Controle com PS5 como base

- O projeto deve nascer com mentalidade `pad-first`, tratando o DualSense como referência principal de navegação e ação.
- Os inputs devem ser organizados por ações abstratas, para que a UI possa exibir prompts corretos do PlayStation sem acoplar a lógica a teclas específicas.
- Teclado e mouse podem ser adicionados depois, mas sem virar a prioridade estrutural do protótipo.
- A camada de UI já deve ser pensada para suportar prompts contextuais, confirmação, cancelamento, navegação e interação com foco em controle.

## Addons encontrados e uso provável

Observação: no snapshot atual do workspace em 04/04/2026, a pasta `res://addons/` não apareceu versionada. As observações abaixo usam a lista fornecida no pedido, e nenhuma alteração foi feita em addons.

### Mais úteis agora ou no curto prazo

- `dialogue_manager`: forte candidato para prólogo, conversas e primeiras escolhas narrativas.
- `input_prompts`: útil para mostrar prompts corretos de DualSense na UI.
- `real-controller`: útil para detecção e padronização de controle PlayStation.
- `quest_system`: bom candidato para objetivos simples do prólogo e primeiros passos.
- `game_state_saver`: útil para salvar dados básicos do personagem e a origem escolhida.
- `godot_audio_manager`: útil para organizar música e efeitos sem improviso estrutural.

### Úteis quando o protótipo começar a ficar mais jogável

- `health_hitbox_hurtbox`: provável base para interações de dano quando houver gameplay de ação.
- `Input_buffer_combo_system`: útil se o combate caminhar para timing e combos.
- `dialog`: pode ser útil, mas parece sobrepor parte do papel de `dialogue_manager`.

### Mais adequados para fases posteriores

- `beehave`: IA baseada em behavior tree, mais útil quando houver inimigos complexos.
- `limboai`: também parece focado em IA e possivelmente sobrepõe `beehave`.
- `GD-Sync`: parece voltado a sincronização e multiplayer, fora do escopo atual.
- `inventory-system`: melhor deixar para quando o loop principal já estiver validado.
- `inventory-system-demos`: referência apenas, sem necessidade neste passo.
- `terrain_3d`: útil se o projeto crescer para ambientes 3D mais robustos.
- `UniParticles3D`: mais relevante para polish visual posterior.
- `worldmap_builder`: provável candidato para mapa de mundo mais tarde.
- `wyvernbox`: pelo nome, parece servir a estruturas de gameplay mais amplas, melhor avaliar depois.
- `wyvernbox_prefabs`: dependente da decisão sobre `wyvernbox`.
- `humanizer`: função incerta pelo nome, melhor avaliar com necessidade concreta.

### Observações de sobreposição para decidir depois

- `dialog` e `dialogue_manager` parecem cobrir áreas próximas de diálogo.
- `beehave` e `limboai` parecem cobrir áreas próximas de IA.
- `inventory-system` e `wyvernbox` podem disputar espaço dependendo da abordagem de inventário e progressão.

## Estrutura de pastas criada

```text
res://game/
  autoload/
  core/
  data/
    player/
    gameplay/
    dialogue/
    quests/
    narrative/
  scenes/
    bootstrap/
    menus/
    ui/
    prologue/
    character_creation/
    origin_choice/
    hub/
    combat/
    common/
  actors/
    player/
    enemies/
    npcs/
  systems/
    input/
    dialogue/
    save/
    quests/
    reputation/
    combat/
    progression/
    narrative/
  assets/
    audio/
    music/
    sfx/
    ui/
    vfx/
    models/
    materials/
    textures/
  docs/
  prototypes/
  debug/
  test_scenes/
```

## Próximos 3 a 5 passos ideais

1. Criar uma cena de bootstrap simples para iniciar o protótipo sem mexer no fluxo atual de `NexTactics`.
2. Definir os recursos de dados mínimos do protagonista e da escolha de origem.
3. Preparar o mapa de input `pad-first` e a camada de prompts PlayStation.
4. Montar o fluxo mínimo jogável: rotina civil, prólogo, criação de personagem e escolha entre laboratório e academia.
5. Criar um hub ou cena-teste curta para validar a primeira consequência prática da escolha inicial.
