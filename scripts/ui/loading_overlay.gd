extends CanvasLayer
## Full-screen outpost load UI: progress bar, rotating tips, and failure text.

signal dismissed

const TIPS := [
	"Tip: Disable alarms before the garrison radios for backup.",
	"Tip: Headshots drop every hostile — even heavies — in one hit.",
	"Tip: Dogs hear farther than soldiers. Circle wide or take the handler first.",
	"Tip: Officers sprint to alarms. Silence them early.",
	"Tip: Look-swipes never fire. Only the on-screen FIRE button shoots.",
	"Tip: Multi-storey interiors hide patrols on stairs and rooftops.",
	"Tip: Liberate quietly — loud runs bring denser reinforcements.",
	"Tip: Use Peek L / Peek R to check corners without exposing yourself.",
]

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Center/VBox/Title
@onready var stage_label: Label = $Center/VBox/StageLabel
@onready var bar: ProgressBar = $Center/VBox/Progress
@onready var tip_label: Label = $Center/VBox/Tip
@onready var error_label: Label = $Center/VBox/ErrorLabel
@onready var detail_label: Label = $Center/VBox/DetailLabel

var _tip_idx: int = 0
var _tip_timer: float = 0.0
var _errors: PackedStringArray = []


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_tip_idx = randi() % TIPS.size()
	tip_label.text = TIPS[_tip_idx]
	error_label.text = ""
	error_label.visible = false
	set_progress(0.0, "Preparing outpost…")


func _process(delta: float) -> void:
	if not visible:
		return
	_tip_timer += delta
	if _tip_timer >= 4.2:
		_tip_timer = 0.0
		_tip_idx = (_tip_idx + 1) % TIPS.size()
		tip_label.text = TIPS[_tip_idx]


func set_progress(p: float, stage: String, detail: String = "") -> void:
	bar.value = clampf(p, 0.0, 1.0) * 100.0
	stage_label.text = stage
	if detail != "":
		detail_label.text = detail
	detail_label.visible = detail != ""


func report_error(msg: String) -> void:
	_errors.append(msg)
	error_label.visible = true
	error_label.text = "Load issue: %s" % msg
	push_error("[OutpostLoad] %s" % msg)
	print("OUTPOST_LOAD_ERROR ", msg)


func has_errors() -> bool:
	return not _errors.is_empty()


func finish_ok(msg: String = "Ready — deploying…") -> void:
	set_progress(1.0, msg)
	await get_tree().create_timer(0.35).timeout
	visible = false
	dismissed.emit()


func finish_failed(summary: String) -> void:
	set_progress(bar.value / 100.0, "Load incomplete")
	error_label.visible = true
	error_label.text = summary
	# Stay visible so the player can read the failure; auto-hide after a beat
	await get_tree().create_timer(2.4).timeout
	visible = false
	dismissed.emit()
