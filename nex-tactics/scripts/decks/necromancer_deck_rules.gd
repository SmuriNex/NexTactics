extends RefCounted
class_name NecromancerDeckRules

const DECK_ID := "necromancer_deck"

const MASTER_ID := "necromancer_master"
const SKELETON_ID := "necromancer_skeleton"
const TOMB_RAIDER_ID := "tomb_raider"
const SHADOW_CULTIST_ID := "shadow_cultist"
const HUNGRY_GHOUL_ID := "hungry_ghoul"
const FALLEN_KNIGHT_ID := "fallen_knight"
const BONE_KAMIKAZE_ID := "bone_kamikaze"
const SPECTRAL_ELF_BLADE_ID := "spectral_elf_blade"
const IRON_CRYPT_GUARD_ID := "iron_crypt_guard"
const CORRUPTED_RUNE_SQUIRE_ID := "corrupted_rune_squire"
const MOURNING_FAIRY_ID := "mourning_fairy"
const CURSE_WEAVER_ID := "curse_weaver"
const BONE_ORACLE_ID := "bone_oracle"
const REQUIEM_SINGER_ID := "requiem_singer"

const BOOK_OF_CHAOS_ID := "book_of_chaos"
const CLOAK_OF_DARKNESS_ID := "cloak_of_darkness"
const BLINDING_MIST_ID := "blinding_mist"
const BLOOD_PACT_ID := "blood_pact"
const BONE_PRISON_ID := "bone_prison"

func is_necromancer_master(unit_state: BattleUnitState) -> bool:
	return unit_state != null and unit_state.unit_data != null and unit_state.unit_data.id == MASTER_ID

func is_bone_kamikaze(unit_state: BattleUnitState) -> bool:
	return unit_state != null and unit_state.unit_data != null and unit_state.unit_data.id == BONE_KAMIKAZE_ID

func is_skeleton(unit_state: BattleUnitState) -> bool:
	return unit_state != null and unit_state.unit_data != null and unit_state.unit_data.id == SKELETON_ID
