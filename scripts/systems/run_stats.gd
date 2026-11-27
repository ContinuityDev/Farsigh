extends RefCounted
class_name RunStats
## Per-deploy mission stats used for clear payouts and best-score tracking.


var start_msec: int = 0
var spotted: bool = false
var alarm_triggered: bool = false
var headshots: int = 0
var takedowns: int = 0
var bodies_hidden: int = 0
var kills: int = 0
var undetected_streak: int = 0
var best_streak: int = 0


func begin() -> void:
	start_msec = Time.get_ticks_msec()
	spotted = false
	alarm_triggered = false
	headshots = 0
	takedowns = 0
	bodies_hidden = 0
	kills = 0
	undetected_streak = 0
	best_streak = 0


func elapsed_sec() -> float:
	if start_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - start_msec) / 1000.0


func on_spotted() -> void:
	spotted = true
	undetected_streak = 0


func on_alarm() -> void:
	alarm_triggered = true


func on_kill(was_headshot: bool, was_takedown: bool) -> void:
	kills += 1
	if was_headshot:
		headshots += 1
	if was_takedown:
		takedowns += 1
	if not spotted:
		undetected_streak += 1
		best_streak = maxi(best_streak, undetected_streak)
	else:
		# Detected kills still count for streaks if player broke LOS — keep chain only while ghost
		pass


func on_body_hidden() -> void:
	bodies_hidden += 1


func to_dict() -> Dictionary:
	return {
		"undetected": not spotted,
		"no_alarms": not alarm_triggered,
		"headshots": headshots,
		"takedowns": takedowns,
		"bodies_hidden": bodies_hidden,
		"kills": kills,
		"elapsed_sec": elapsed_sec(),
		"best_streak": best_streak,
	}
