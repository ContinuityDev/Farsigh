class_name Foley
extends RefCounted
## Short synthesized weapon foley. No recorded pack ships with the game, so
## these clips are generated: a mag click, a bolt, a shell, a nock, and cloth.


static var _cache: Dictionary = {}


static func play(host: Node, clip: String) -> void:
	if host == null:
		return
	var player := host.get_node_or_null("FoleyPlayer") as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "FoleyPlayer"
		host.add_child(player)
	if not _cache.has(clip):
		_cache[clip] = _make(clip)
	player.stream = _cache[clip]
	player.volume_db = -6.0
	player.play()


static func _make(clip: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.11
	match clip:
		"draw", "holster":
			dur = 0.18
		"bolt":
			dur = 0.2
		"nock":
			dur = 0.16
	var count := int(rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(clip) + 17
	var prev := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var s := 0.0
		match clip:
			"mag_out":
				var env := exp(-t * 22.0)
				s = (rng.randf_range(-1.0, 1.0) * 0.55 + sin(TAU * lerpf(240.0, 90.0, t / dur) * t) * 0.45) * env
			"mag_in":
				var env := exp(-t * 36.0)
				var thump := sin(TAU * 140.0 * t) * exp(-t * 18.0)
				s = (thump * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3) * env
			"bolt":
				var hit := 0.0
				if t < 0.025 or (t > 0.1 and t < 0.13):
					hit = 1.0
				s = rng.randf_range(-1.0, 1.0) * hit + sin(TAU * 900.0 * t) * hit * 0.35
			"shell":
				var env := exp(-t * 48.0)
				s = (rng.randf_range(-1.0, 1.0) * 0.45 + sin(TAU * 320.0 * t) * 0.25) * env
			"nock":
				var env := sin(clampf(t / dur, 0.0, 1.0) * PI)
				s = sin(TAU * lerpf(520.0, 160.0, t / dur) * t) * env * 0.55
			_:
				var env := sin(clampf(t / dur, 0.0, 1.0) * PI)
				s = (prev * 0.72 + rng.randf_range(-1.0, 1.0) * 0.28) * env
		prev = s
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 24000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
