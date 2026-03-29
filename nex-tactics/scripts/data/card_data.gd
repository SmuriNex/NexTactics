extends Resource
class_name CardData

@export var id: String = ""
@export var display_name: String = ""
@export var card_type: int = GameEnums.CardType.CREATURE
@export var cost: int = 1
@export var unit_data: UnitData
@export var support_effect_type: int = GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL
@export var heal_amount: int = 0
@export var global_life_heal: int = 0
@export var magic_attack_multiplier: float = 1.0
@export var physical_attack_multiplier: float = 1.0
@export var physical_defense_multiplier: float = 1.0
@export var effect_duration_turns: int = 0
@export var delayed_trigger_min_turn: int = 0
@export var delayed_trigger_max_turn: int = 0
@export var physical_miss_chance: float = 0.0
@export var mana_ratio_transfer_on_death: float = 0.0
@export var stealth_turns: int = 0
@export var cell_target_enemy_zone: bool = false
@export var stun_turns: int = 0
@export var mana_gain_multiplier: float = 1.0
@export var physical_attack_bonus: int = 0
@export var magic_attack_bonus: int = 0
@export var physical_defense_bonus: int = 0
@export var magic_defense_bonus: int = 0
@export var attack_range_bonus: int = 0
@export var bonus_next_round_gold: int = 0
@export var tribute_steal_amount: int = 0
@export var description: String = ""
