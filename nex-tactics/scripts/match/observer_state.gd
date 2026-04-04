extends RefCounted
class_name ObserverState

enum Mode {
	LOCAL_VIEW,
	REMOTE_VIEW,
	RETURNING_TO_LOCAL,
}

var mode: int = Mode.LOCAL_VIEW
var observed_player_id: String = ""
var observed_table_id: String = ""

func reset() -> void:
	mode = Mode.LOCAL_VIEW
	observed_player_id = ""
	observed_table_id = ""

func enter_remote_view(player_id: String, table_id: String = "") -> void:
	observed_player_id = str(player_id)
	observed_table_id = str(table_id)
	mode = Mode.REMOTE_VIEW if not observed_player_id.is_empty() else Mode.LOCAL_VIEW

func begin_return_to_local() -> void:
	mode = Mode.RETURNING_TO_LOCAL
	observed_player_id = ""
	observed_table_id = ""

func finish_return_to_local() -> void:
	mode = Mode.LOCAL_VIEW
	observed_player_id = ""
	observed_table_id = ""

func is_remote_view() -> bool:
	return mode == Mode.REMOTE_VIEW and not observed_player_id.is_empty()
