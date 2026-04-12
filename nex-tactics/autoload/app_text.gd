extends Node

signal language_changed(language_code: String)

const DEFAULT_LANGUAGE := "pt_BR"
const SUPPORTED_LANGUAGES := [
	{"code": "pt_BR", "native_name": "Português"},
	{"code": "en", "native_name": "English"},
	{"code": "es", "native_name": "Español"},
]

const UI_TEXT := {
	"pt_BR": {
		"app.play": "PLAY",
		"app.deck": "DECK",
		"app.settings": "Configurações",
		"app.back": "Voltar",
		"app.close": "Fechar",
		"start.subtitle": "Auto-battler tático local-first. Escolha um deck, domine o Mestre e leve sua coroa para a guerra.",
		"start.deck_current": "Deck Atual",
		"start.no_deck": "Nenhum deck escolhido",
		"start.open_deck_prompt": "Abra DECK para conhecer os três exércitos.",
		"start.play_unlock_hint": "PLAY fica liberado assim que um deck for selecionado.",
		"start.play_requires_deck": "Escolha um deck antes de iniciar.",
		"start.play_ready": "PLAY inicia a partida com o deck escolhido.",
		"start.master_prefix": "Mestre: {name}",
		"start.no_master": "Sem mestre",
		"settings.title": "Configurações",
		"settings.subtitle": "Idioma, áudio e tela para a build pública.",
		"settings.language": "Idioma",
		"settings.audio": "Áudio",
		"settings.master_volume": "Volume geral",
		"settings.display": "Tela",
		"settings.window_mode": "Modo de janela",
		"settings.windowed": "Janela",
		"settings.fullscreen": "Tela cheia",
		"settings.saved": "As configurações são aplicadas e salvas automaticamente.",
		"deck.title": "DECK",
		"deck.subtitle": "Escolha um deck, entenda o Mestre e conheça suas unidades e cartas antes de iniciar a partida.",
		"deck.current_selection": "Selecionado: {name}",
		"deck.selected_none": "Nenhum",
		"deck.list_title": "Decks disponíveis",
		"deck.list_subtitle": "Rei Thrax, Mordos, o Necromante, e A Dama do Lago.",
		"deck.selection_prompt": "Selecione um deck para liberar PLAY.",
		"deck.overview_title": "Deck",
		"deck.master_title": "Mestre",
		"deck.how_title": "Como funciona",
		"deck.how_step_1": "1. Escolha um deck e leve seu Mestre para a partida.",
		"deck.how_step_2": "2. No PREP, você posiciona unidades, usa supports e administra espaço.",
		"deck.how_step_3": "3. O Mestre ganha XP, sobe de nível, abre mais campo e libera promoções durante a match.",
		"deck.units_title": "Unidades do deck",
		"deck.cards_title": "Cartas / supports",
		"deck.action_selected": "Este deck já está pronto para PLAY.",
		"deck.action_selected_hint": "Volte para PLAY na tela inicial quando quiser iniciar a partida.",
		"deck.action_select": "Selecione este deck para liberar PLAY na tela inicial.",
		"deck.action_select_hint": "Confirme o deck aqui e depois use PLAY na tela inicial.",
		"deck.button_selected": "Deck selecionado",
		"deck.button_select": "Selecionar este deck",
		"deck.badge_selected": "[SELECIONADO]",
		"deck.line_deck": "Deck: {value}",
		"deck.line_factions": "Facções: {value}",
		"deck.line_playstyle": "Estilo: {value}",
		"deck.line_summary": "Resumo: {value}",
		"deck.line_master_role": "Papel: {value}",
		"deck.line_master_identity": "Identidade: {value}",
		"deck.line_master_signature": "Habilidade/assinatura: {value}",
		"deck.line_master_progression": "Progressão: o Mestre é o centro do XP, da capacidade do campo e das promoções da partida.",
		"deck.free_card": "Grátis na partida",
		"deck.no_master_description": "Centro da progressão da partida.",
		"hud.round": "RODADA {round}",
		"hud.life": "Vida         {value}",
		"hud.gold": "Ouro         {value}",
		"hud.gold_income": "Ouro         {value} (+{income})",
		"hud.state": "Estado       {value}",
		"hud.opponent": "Oponente     {value}",
		"hud.observing": "OBSERVANDO: {name}",
		"hud.observing_vs": "OBSERVANDO: {name_a} vs {name_b}",
		"hud.observing_empty": "OBSERVANDO: -",
		"hud.return_board": "Voltar para meu tabuleiro",
		"hud.supports_title": "SUPPORTS DA PARTIDA",
		"hud.supports_subtitle": "Globais ativam sozinhos. Táticos pedem alvo no PREP.",
		"hud.unit_info_title": "Info da unidade",
		"hud.unit_info_cost": "Mana -",
		"hud.unit_info_subtitle": "Clique numa unidade para ler detalhes. Clique no vazio para voltar aos supports.",
		"hud.section_unit": "UNIDADE",
		"hud.section_stats": "ATRIBUTOS",
		"hud.section_skill": "PASSIVA E ATIVA",
		"hud.section_effects": "EFEITOS ATIVOS",
		"hud.card_shop_title": "LOJA DA PARTIDA - RODADA {round}",
		"hud.card_shop_subtitle": "Escolha 1 carta gratuita. O PREP fica pausado até você decidir.",
		"hud.card_unavailable": "Carta indisponível",
		"hud.click_to_choose": "CLIQUE PARA ESCOLHER",
		"hud.free_short": "Grátis",
		"hud.eliminated_title": "VOCÊ FOI ELIMINADO",
		"hud.placement": "Sua posição final: {value}",
		"hud.eliminated_body": "Você pode continuar assistindo em observer ou voltar para a tela inicial.",
		"hud.watch_to_end": "Assistir até o fim",
		"hud.return_start": "Voltar ao início",
		"hud.match_end": "FIM DA PARTIDA",
		"hud.ranking_full": "Ranking completo:\n{value}",
		"hud.ranking_unavailable": "Ranking indisponível.",
		"hud.winner_units": "Peças finais do vencedor ({name}):\n{value}",
		"hud.winner_unavailable": "Composição final indisponível.",
		"hud.total_damage": "Dano total causado na partida: {value}",
		"hud.play_again": "Jogar novamente",
		"deploy.sell_area": "ÁREA DE VENDA",
		"deploy.drag_to_sell": "Arraste a unidade",
		"deploy.drop_to_sell": "Solte para vender",
		"deploy.invalid": "Inválido",
		"deploy.cost": "Custo: {value}",
		"deploy.status_ready": "PRONTO",
		"deploy.status_used": "USADO",
		"deploy.status_armed": "ARMADO",
		"deploy.status_dragging": "ARRAST.",
		"deploy.status_no_gold": "SEM OURO",
		"deploy.status_unavailable": "INDISP.",
		"deploy.support_available": "DISPONÍVEL",
		"deploy.support_used": "USADA",
		"deploy.support_selected": "ARMADA",
		"deploy.support_unavailable": "INDISPONÍVEL",
		"match.state_setup": "SETUP",
		"match.state_prep": "PREPARAÇÃO",
		"match.state_battle": "BATALHA",
		"match.state_round_end": "FIM_DA_RODADA",
		"match.state_match_end": "FIM_DA_PARTIDA",
		"match.state_unknown": "DESCONHECIDO",
		"match.phase_lobby": "LOBBY",
		"match.phase_pairing": "PAREAMENTO",
		"match.phase_prep": "PREPARAÇÃO",
		"match.phase_battle": "BATALHA",
		"match.phase_result": "RESULTADO",
		"match.phase_end": "FIM",
		"match.phase_unknown": "DESCONHECIDO",
		"match.observer_lobby": "Observer do lobby",
		"match.player_eliminated": "Jogador eliminado",
		"match.bye": "Bye técnico",
		"match.waiting_pairing": "Aguardando pareamento",
		"match.hidden_opponent": "???",
		"match.no_combat": "Sem combate",
		"match.default_player": "Jogador",
		"match.default_player_a": "Jogador A",
		"match.default_player_b": "Jogador B",
		"match.top_place": "Top {placement}",
		"match.ranking_entry": "Top {placement} - {name}",
		"master.status": "Mestre Nv {level} | XP {xp} | Campo {units}/{capacity}",
		"master.recovery": "Recuperação",
		"master.xp_gain": "XP +{value}",
		"master.recovery_bonus": "Recuperação +{value}",
		"master.level_gain": "Nv {value}",
		"master.field_gain": "Campo {value}",
		"master.promotion_gain": "Promoção +{value}",
		"master.pending_promotion": "Promoção pendente x{value}",
		"master.drag_promotion": "Arraste a ficha do Mestre para promover",
		"support.free_cost": "GRÁTIS",
		"support.type_default": "SUPORTE",
		"support.empty_title": "Carta indisponível",
		"support.empty_caption": "Sem dados",
		"support.empty_description": "Recurso ausente.",
		"support.footer_ready": "DISPONÍVEL",
		"support.footer_selected": "ARMADA",
		"support.footer_auto": "ATIVA",
		"support.footer_used": "USADA",
		"support.footer_unavailable": "INDISPONÍVEL",
		"support.description_fallback": "Suporte de preparo com efeito especial.",
	},
	"en": {
		"app.play": "PLAY",
		"app.deck": "DECK",
		"app.settings": "Settings",
		"app.back": "Back",
		"app.close": "Close",
		"start.subtitle": "Local-first tactical auto-battler. Pick a deck, command your Master, and claim the crown through war.",
		"start.deck_current": "Current Deck",
		"start.no_deck": "No deck selected",
		"start.open_deck_prompt": "Open DECK to inspect the three armies.",
		"start.play_unlock_hint": "PLAY becomes available as soon as you select a deck.",
		"start.play_requires_deck": "Choose a deck before starting.",
		"start.play_ready": "PLAY starts the match with the selected deck.",
		"start.master_prefix": "Master: {name}",
		"start.no_master": "No master",
		"settings.title": "Settings",
		"settings.subtitle": "Language, audio, and display options for the public build.",
		"settings.language": "Language",
		"settings.audio": "Audio",
		"settings.master_volume": "Master volume",
		"settings.display": "Display",
		"settings.window_mode": "Window mode",
		"settings.windowed": "Windowed",
		"settings.fullscreen": "Fullscreen",
		"settings.saved": "Settings are applied and saved automatically.",
		"deck.title": "DECK",
		"deck.subtitle": "Choose a deck, learn your Master, and review units and cards before the match begins.",
		"deck.current_selection": "Selected: {name}",
		"deck.selected_none": "None",
		"deck.list_title": "Available decks",
		"deck.list_subtitle": "King Thrax, Mordos the Necromancer, and The Lady of the Lake.",
		"deck.selection_prompt": "Select a deck to unlock PLAY.",
		"deck.overview_title": "Deck",
		"deck.master_title": "Master",
		"deck.how_title": "How it works",
		"deck.how_step_1": "1. Choose a deck and bring its Master into the match.",
		"deck.how_step_2": "2. During PREP, you position units, use supports, and manage space.",
		"deck.how_step_3": "3. Your Master gains XP, levels up, expands the field, and unlocks promotions during the match.",
		"deck.units_title": "Deck units",
		"deck.cards_title": "Cards / supports",
		"deck.action_selected": "This deck is already ready for PLAY.",
		"deck.action_selected_hint": "Go back to PLAY on the home screen whenever you want to start.",
		"deck.action_select": "Select this deck to unlock PLAY on the home screen.",
		"deck.action_select_hint": "Confirm the deck here, then use PLAY on the home screen.",
		"deck.button_selected": "Deck selected",
		"deck.button_select": "Select this deck",
		"deck.badge_selected": "[SELECTED]",
		"deck.line_deck": "Deck: {value}",
		"deck.line_factions": "Factions: {value}",
		"deck.line_playstyle": "Style: {value}",
		"deck.line_summary": "Summary: {value}",
		"deck.line_master_role": "Role: {value}",
		"deck.line_master_identity": "Identity: {value}",
		"deck.line_master_signature": "Signature: {value}",
		"deck.line_master_progression": "Progression: the Master is the center of XP, field capacity, and promotions during the match.",
		"deck.free_card": "Free during the match",
		"deck.no_master_description": "Center of the match progression loop.",
		"hud.round": "ROUND {round}",
		"hud.life": "Life         {value}",
		"hud.gold": "Gold         {value}",
		"hud.gold_income": "Gold         {value} (+{income})",
		"hud.state": "State        {value}",
		"hud.opponent": "Opponent     {value}",
		"hud.observing": "OBSERVING: {name}",
		"hud.observing_vs": "OBSERVING: {name_a} vs {name_b}",
		"hud.observing_empty": "OBSERVING: -",
		"hud.return_board": "Return to my board",
		"hud.supports_title": "MATCH SUPPORTS",
		"hud.supports_subtitle": "Global cards trigger automatically. Tactical cards need a PREP target.",
		"hud.unit_info_title": "Unit info",
		"hud.unit_info_cost": "Mana -",
		"hud.unit_info_subtitle": "Click a unit to inspect it. Click empty space to return to supports.",
		"hud.section_unit": "UNIT",
		"hud.section_stats": "STATS",
		"hud.section_skill": "PASSIVE AND ACTIVE",
		"hud.section_effects": "ACTIVE EFFECTS",
		"hud.card_shop_title": "MATCH SHOP - ROUND {round}",
		"hud.card_shop_subtitle": "Choose 1 free card. PREP stays paused until you decide.",
		"hud.card_unavailable": "Card unavailable",
		"hud.click_to_choose": "CLICK TO CHOOSE",
		"hud.free_short": "Free",
		"hud.eliminated_title": "YOU WERE ELIMINATED",
		"hud.placement": "Final placement: {value}",
		"hud.eliminated_body": "You can keep watching in observer mode or return to the home screen.",
		"hud.watch_to_end": "Watch to the end",
		"hud.return_start": "Return to start",
		"hud.match_end": "MATCH OVER",
		"hud.ranking_full": "Full ranking:\n{value}",
		"hud.ranking_unavailable": "Ranking unavailable.",
		"hud.winner_units": "Winner final board ({name}):\n{value}",
		"hud.winner_unavailable": "Final composition unavailable.",
		"hud.total_damage": "Total damage dealt in the match: {value}",
		"hud.play_again": "Play again",
		"deploy.sell_area": "SELL AREA",
		"deploy.drag_to_sell": "Drag a unit here",
		"deploy.drop_to_sell": "Drop to sell",
		"deploy.invalid": "Invalid",
		"deploy.cost": "Cost: {value}",
		"deploy.status_ready": "READY",
		"deploy.status_used": "USED",
		"deploy.status_armed": "ARMED",
		"deploy.status_dragging": "DRAG",
		"deploy.status_no_gold": "NO GOLD",
		"deploy.status_unavailable": "LOCKED",
		"deploy.support_available": "AVAILABLE",
		"deploy.support_used": "USED",
		"deploy.support_selected": "ARMED",
		"deploy.support_unavailable": "UNAVAILABLE",
		"match.state_setup": "SETUP",
		"match.state_prep": "PREP",
		"match.state_battle": "BATTLE",
		"match.state_round_end": "ROUND_END",
		"match.state_match_end": "MATCH_END",
		"match.state_unknown": "UNKNOWN",
		"match.phase_lobby": "LOBBY",
		"match.phase_pairing": "PAIRING",
		"match.phase_prep": "PREP",
		"match.phase_battle": "BATTLE",
		"match.phase_result": "RESULT",
		"match.phase_end": "END",
		"match.phase_unknown": "UNKNOWN",
		"match.observer_lobby": "Lobby observer",
		"match.player_eliminated": "Eliminated player",
		"match.bye": "Technical bye",
		"match.waiting_pairing": "Waiting for pairing",
		"match.hidden_opponent": "???",
		"match.no_combat": "No combat",
		"match.default_player": "Player",
		"match.default_player_a": "Player A",
		"match.default_player_b": "Player B",
		"match.top_place": "Top {placement}",
		"match.ranking_entry": "Top {placement} - {name}",
		"master.status": "Master Lv {level} | XP {xp} | Field {units}/{capacity}",
		"master.recovery": "Recovery",
		"master.xp_gain": "XP +{value}",
		"master.recovery_bonus": "Recovery +{value}",
		"master.level_gain": "Lv {value}",
		"master.field_gain": "Field {value}",
		"master.promotion_gain": "Promotion +{value}",
		"master.pending_promotion": "Pending promotion x{value}",
		"master.drag_promotion": "Drag the Master token to promote",
		"support.free_cost": "FREE",
		"support.type_default": "SUPPORT",
		"support.empty_title": "Card unavailable",
		"support.empty_caption": "No data",
		"support.empty_description": "Missing resource.",
		"support.footer_ready": "AVAILABLE",
		"support.footer_selected": "ARMED",
		"support.footer_auto": "ACTIVE",
		"support.footer_used": "USED",
		"support.footer_unavailable": "UNAVAILABLE",
		"support.description_fallback": "Prep support with a special effect.",
	},
	"es": {
		"app.play": "PLAY",
		"app.deck": "DECK",
		"app.settings": "Configuración",
		"app.back": "Volver",
		"app.close": "Cerrar",
		"start.subtitle": "Auto-battler táctico local-first. Elige un deck, lidera a tu Maestro y conquista la corona en la guerra.",
		"start.deck_current": "Deck actual",
		"start.no_deck": "Ningún deck seleccionado",
		"start.open_deck_prompt": "Abre DECK para conocer los tres ejércitos.",
		"start.play_unlock_hint": "PLAY se habilita en cuanto selecciones un deck.",
		"start.play_requires_deck": "Elige un deck antes de empezar.",
		"start.play_ready": "PLAY inicia la partida con el deck elegido.",
		"start.master_prefix": "Maestro: {name}",
		"start.no_master": "Sin maestro",
		"settings.title": "Configuración",
		"settings.subtitle": "Idioma, audio y pantalla para la build pública.",
		"settings.language": "Idioma",
		"settings.audio": "Audio",
		"settings.master_volume": "Volumen general",
		"settings.display": "Pantalla",
		"settings.window_mode": "Modo de ventana",
		"settings.windowed": "Ventana",
		"settings.fullscreen": "Pantalla completa",
		"settings.saved": "La configuración se aplica y se guarda automáticamente.",
		"deck.title": "DECK",
		"deck.subtitle": "Elige un deck, entiende a tu Maestro y revisa unidades y cartas antes de iniciar la partida.",
		"deck.current_selection": "Seleccionado: {name}",
		"deck.selected_none": "Ninguno",
		"deck.list_title": "Decks disponibles",
		"deck.list_subtitle": "Rey Thrax, Mordos el Nigromante y La Dama del Lago.",
		"deck.selection_prompt": "Selecciona un deck para habilitar PLAY.",
		"deck.overview_title": "Deck",
		"deck.master_title": "Maestro",
		"deck.how_title": "Cómo funciona",
		"deck.how_step_1": "1. Elige un deck y lleva a tu Maestro a la partida.",
		"deck.how_step_2": "2. En PREP colocas unidades, usas supports y administras el espacio.",
		"deck.how_step_3": "3. El Maestro gana XP, sube de nivel, abre más campo y libera promociones durante la partida.",
		"deck.units_title": "Unidades del deck",
		"deck.cards_title": "Cartas / supports",
		"deck.action_selected": "Este deck ya está listo para PLAY.",
		"deck.action_selected_hint": "Vuelve a PLAY en la pantalla inicial cuando quieras empezar.",
		"deck.action_select": "Selecciona este deck para habilitar PLAY en la pantalla inicial.",
		"deck.action_select_hint": "Confirma el deck aquí y luego usa PLAY en la pantalla inicial.",
		"deck.button_selected": "Deck seleccionado",
		"deck.button_select": "Seleccionar este deck",
		"deck.badge_selected": "[SELECCIONADO]",
		"deck.line_deck": "Deck: {value}",
		"deck.line_factions": "Facciones: {value}",
		"deck.line_playstyle": "Estilo: {value}",
		"deck.line_summary": "Resumen: {value}",
		"deck.line_master_role": "Rol: {value}",
		"deck.line_master_identity": "Identidad: {value}",
		"deck.line_master_signature": "Firma: {value}",
		"deck.line_master_progression": "Progresión: el Maestro es el centro del XP, de la capacidad del campo y de las promociones de la partida.",
		"deck.free_card": "Gratis durante la partida",
		"deck.no_master_description": "Centro de la progresión de la partida.",
		"hud.round": "RONDA {round}",
		"hud.life": "Vida         {value}",
		"hud.gold": "Oro          {value}",
		"hud.gold_income": "Oro          {value} (+{income})",
		"hud.state": "Estado       {value}",
		"hud.opponent": "Oponente     {value}",
		"hud.observing": "OBSERVANDO: {name}",
		"hud.observing_vs": "OBSERVANDO: {name_a} vs {name_b}",
		"hud.observing_empty": "OBSERVANDO: -",
		"hud.return_board": "Volver a mi tablero",
		"hud.supports_title": "SUPPORTS DE LA PARTIDA",
		"hud.supports_subtitle": "Los globales se activan solos. Los tácticos necesitan un objetivo en PREP.",
		"hud.unit_info_title": "Info de la unidad",
		"hud.unit_info_cost": "Maná -",
		"hud.unit_info_subtitle": "Haz clic en una unidad para verla. Haz clic en un espacio vacío para volver a supports.",
		"hud.section_unit": "UNIDAD",
		"hud.section_stats": "ATRIBUTOS",
		"hud.section_skill": "PASIVA Y ACTIVA",
		"hud.section_effects": "EFECTOS ACTIVOS",
		"hud.card_shop_title": "TIENDA DE LA PARTIDA - RONDA {round}",
		"hud.card_shop_subtitle": "Elige 1 carta gratis. PREP queda en pausa hasta que decidas.",
		"hud.card_unavailable": "Carta no disponible",
		"hud.click_to_choose": "HAZ CLIC PARA ELEGIR",
		"hud.free_short": "Gratis",
		"hud.eliminated_title": "HAS SIDO ELIMINADO",
		"hud.placement": "Posición final: {value}",
		"hud.eliminated_body": "Puedes seguir observando o volver a la pantalla inicial.",
		"hud.watch_to_end": "Ver hasta el final",
		"hud.return_start": "Volver al inicio",
		"hud.match_end": "FIN DE LA PARTIDA",
		"hud.ranking_full": "Ranking completo:\n{value}",
		"hud.ranking_unavailable": "Ranking no disponible.",
		"hud.winner_units": "Piezas finales del ganador ({name}):\n{value}",
		"hud.winner_unavailable": "Composición final no disponible.",
		"hud.total_damage": "Daño total causado en la partida: {value}",
		"hud.play_again": "Jugar de nuevo",
		"deploy.sell_area": "ÁREA DE VENTA",
		"deploy.drag_to_sell": "Arrastra una unidad",
		"deploy.drop_to_sell": "Suelta para vender",
		"deploy.invalid": "Inválido",
		"deploy.cost": "Costo: {value}",
		"deploy.status_ready": "LISTO",
		"deploy.status_used": "USADO",
		"deploy.status_armed": "ARMADA",
		"deploy.status_dragging": "ARRAST.",
		"deploy.status_no_gold": "SIN ORO",
		"deploy.status_unavailable": "BLOQ.",
		"deploy.support_available": "DISPONIBLE",
		"deploy.support_used": "USADA",
		"deploy.support_selected": "ARMADA",
		"deploy.support_unavailable": "NO DISP.",
		"match.state_setup": "SETUP",
		"match.state_prep": "PREPARACIÓN",
		"match.state_battle": "BATALLA",
		"match.state_round_end": "FIN_DE_RONDA",
		"match.state_match_end": "FIN_DE_PARTIDA",
		"match.state_unknown": "DESCONOCIDO",
		"match.phase_lobby": "LOBBY",
		"match.phase_pairing": "EMPAREJAMIENTO",
		"match.phase_prep": "PREPARACIÓN",
		"match.phase_battle": "BATALLA",
		"match.phase_result": "RESULTADO",
		"match.phase_end": "FIN",
		"match.phase_unknown": "DESCONOCIDO",
		"match.observer_lobby": "Observer del lobby",
		"match.player_eliminated": "Jugador eliminado",
		"match.bye": "Bye técnico",
		"match.waiting_pairing": "Esperando emparejamiento",
		"match.hidden_opponent": "???",
		"match.no_combat": "Sin combate",
		"match.default_player": "Jugador",
		"match.default_player_a": "Jugador A",
		"match.default_player_b": "Jugador B",
		"match.top_place": "Top {placement}",
		"match.ranking_entry": "Top {placement} - {name}",
		"master.status": "Maestro Nv {level} | XP {xp} | Campo {units}/{capacity}",
		"master.recovery": "Recuperación",
		"master.xp_gain": "XP +{value}",
		"master.recovery_bonus": "Recuperación +{value}",
		"master.level_gain": "Nv {value}",
		"master.field_gain": "Campo {value}",
		"master.promotion_gain": "Promoción +{value}",
		"master.pending_promotion": "Promoción pendiente x{value}",
		"master.drag_promotion": "Arrastra la ficha del Maestro para promover",
		"support.free_cost": "GRATIS",
		"support.type_default": "SUPPORT",
		"support.empty_title": "Carta no disponible",
		"support.empty_caption": "Sin datos",
		"support.empty_description": "Recurso ausente.",
		"support.footer_ready": "DISPONIBLE",
		"support.footer_selected": "ARMADA",
		"support.footer_auto": "ACTIVA",
		"support.footer_used": "USADA",
		"support.footer_unavailable": "NO DISPONIBLE",
		"support.description_fallback": "Support de preparación con efecto especial.",
	},
}

var current_language: String = DEFAULT_LANGUAGE

func _ready() -> void:
	current_language = normalize_language_code(current_language)

func get_supported_languages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in SUPPORTED_LANGUAGES:
		result.append((entry as Dictionary).duplicate(true))
	return result

func normalize_language_code(language_code: String) -> String:
	for entry in SUPPORTED_LANGUAGES:
		if str(entry.get("code", "")) == language_code:
			return language_code
	return DEFAULT_LANGUAGE

func set_language(language_code: String) -> String:
	var resolved_code: String = normalize_language_code(language_code)
	if current_language == resolved_code:
		return current_language
	current_language = resolved_code
	language_changed.emit(current_language)
	return current_language

func text(key: String, params: Dictionary = {}) -> String:
	var locale_map: Dictionary = UI_TEXT.get(current_language, UI_TEXT[DEFAULT_LANGUAGE])
	var fallback_map: Dictionary = UI_TEXT[DEFAULT_LANGUAGE]
	var base_text: String = str(locale_map.get(key, fallback_map.get(key, key)))
	return _format_text(base_text, params)

func race_name(race: int) -> String:
	match current_language:
		"en":
			return _race_name_en(race)
		"es":
			return _race_name_es(race)
		_:
			return _race_name_pt(race)

func class_label(class_type: int) -> String:
	match current_language:
		"en":
			return _class_name_en(class_type)
		"es":
			return _class_name_es(class_type)
		_:
			return _class_name_pt(class_type)

func support_type_name(effect_type: int) -> String:
	match current_language:
		"en":
			return _support_type_name_en(effect_type)
		"es":
			return _support_type_name_es(effect_type)
		_:
			return _support_type_name_pt(effect_type)

func support_target_name(effect_type: int) -> String:
	match current_language:
		"en":
			return _support_target_name_en(effect_type)
		"es":
			return _support_target_name_es(effect_type)
		_:
			return _support_target_name_pt(effect_type)

func _format_text(value: String, params: Dictionary) -> String:
	var formatted: String = value
	for param_key in params.keys():
		formatted = formatted.replace("{%s}" % str(param_key), str(params[param_key]))
	return formatted

func _race_name_pt(race: int) -> String:
	match race:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.FAIRY:
			return "Fada"
		GameEnums.Race.UNDEAD:
			return "Morto-vivo"
		GameEnums.Race.BEAST:
			return "Besta"
		_:
			return "Raça"

func _race_name_en(race: int) -> String:
	match race:
		GameEnums.Race.HUMAN:
			return "Human"
		GameEnums.Race.ELF:
			return "Elf"
		GameEnums.Race.OGRE:
			return "Ogre"
		GameEnums.Race.FAIRY:
			return "Fairy"
		GameEnums.Race.UNDEAD:
			return "Undead"
		GameEnums.Race.BEAST:
			return "Beast"
		_:
			return "Race"

func _race_name_es(race: int) -> String:
	match race:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.FAIRY:
			return "Hada"
		GameEnums.Race.UNDEAD:
			return "No-muerto"
		GameEnums.Race.BEAST:
			return "Bestia"
		_:
			return "Raza"

func _class_name_pt(class_type: int) -> String:
	match class_type:
		GameEnums.ClassType.ATTACKER:
			return "Atacante"
		GameEnums.ClassType.TANK:
			return "Tanque"
		GameEnums.ClassType.SNIPER:
			return "Atirador"
		GameEnums.ClassType.SUPPORT:
			return "Suporte"
		GameEnums.ClassType.STEALTH:
			return "Furtivo"
		_:
			return "Classe"

func _class_name_en(class_type: int) -> String:
	match class_type:
		GameEnums.ClassType.ATTACKER:
			return "Attacker"
		GameEnums.ClassType.TANK:
			return "Tank"
		GameEnums.ClassType.SNIPER:
			return "Sniper"
		GameEnums.ClassType.SUPPORT:
			return "Support"
		GameEnums.ClassType.STEALTH:
			return "Stealth"
		_:
			return "Class"

func _class_name_es(class_type: int) -> String:
	match class_type:
		GameEnums.ClassType.ATTACKER:
			return "Atacante"
		GameEnums.ClassType.TANK:
			return "Tanque"
		GameEnums.ClassType.SNIPER:
			return "Francotirador"
		GameEnums.ClassType.SUPPORT:
			return "Soporte"
		GameEnums.ClassType.STEALTH:
			return "Sigilo"
		_:
			return "Clase"

func _support_type_name_pt(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Suporte global"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Suporte de unidade"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Equipamento mágico"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Equipamento furtivo"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Feitiço de campo"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Suporte de gatilho"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Armadilha de célula"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Feitiço de ouro"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Feitiço de pilhagem"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Equipamento defensivo"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Equipamento ofensivo"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Armadilha de abertura"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Feitiço de campo"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Invocação condicional"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Equipamento místico"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Equipamento ofensivo"
		_:
			return "Suporte"

func _support_type_name_en(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Global support"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Unit support"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Magic equipment"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Stealth equipment"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Field spell"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Trigger support"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Cell trap"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Gold spell"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Tribute spell"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Defensive equipment"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Offensive equipment"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Opening trap"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Field spell"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Conditional summon"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Mystic equipment"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Offensive equipment"
		_:
			return "Support"

func _support_type_name_es(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Soporte global"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Soporte de unidad"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Equipo mágico"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Equipo sigiloso"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Hechizo de campo"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Soporte de gatillo"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Trampa de celda"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Hechizo de oro"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Hechizo de tributo"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Equipo defensivo"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Equipo ofensivo"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Trampa de apertura"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Hechizo de campo"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Invocación condicional"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Equipo místico"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Equipo ofensivo"
		_:
			return "Support"

func _support_target_name_pt(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Mestre aliado"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF, GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER, GameEnums.SupportCardEffectType.START_STEALTH, GameEnums.SupportCardEffectType.DEATH_MANA_PACT, GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF, GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF, GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF, GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Campo instantâneo"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Célula inimiga"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD, GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL, GameEnums.SupportCardEffectType.OPENING_REPOSITION, GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD, GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Sem alvo"
		_:
			return "Desconhecido"

func _support_target_name_en(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Allied Master"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF, GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER, GameEnums.SupportCardEffectType.START_STEALTH, GameEnums.SupportCardEffectType.DEATH_MANA_PACT, GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF, GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF, GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF, GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Allied unit"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Instant field"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Enemy cell"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD, GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL, GameEnums.SupportCardEffectType.OPENING_REPOSITION, GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD, GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "No target"
		_:
			return "Unknown"

func _support_target_name_es(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Maestro aliado"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF, GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER, GameEnums.SupportCardEffectType.START_STEALTH, GameEnums.SupportCardEffectType.DEATH_MANA_PACT, GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF, GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF, GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF, GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Unidad aliada"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Campo instantáneo"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Celda enemiga"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD, GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL, GameEnums.SupportCardEffectType.OPENING_REPOSITION, GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD, GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Sin objetivo"
		_:
			return "Desconocido"
