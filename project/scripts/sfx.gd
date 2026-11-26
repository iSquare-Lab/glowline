class_name Sfx
extends Node
## Small garden sounds made in code (no audio files): a wooden tok for a turn, a softer knock for a lock,
## a wind chime when a lantern lights and a rising kalimba run when the board is solved.

const RATE := 22050

var enabled := true
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_sounds["turn"] = _wood(196.0, 0.09, 0.5)
	_sounds["lock"] = _wood(131.0, 0.12, 0.42)
	_sounds["lantern"] = _chime([1568.0, 2349.3], 1.1, 0.13)
	_sounds["solved"] = _kalimba([587.3, 659.3, 784.0, 880.0, 1174.7], 0.11, 1.6)
	for i in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound_name: String) -> void:
	if not enabled or not _sounds.has(sound_name):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[sound_name]
	player.play()


## A short knock on wood: a low tone that dies fast, with a soft filtered click on top.
func _wood(pitch: float, seconds: float, volume: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch)
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise := 0.0
	for n in count:
		var t := float(n) / RATE
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.25)
		var body := sin(TAU * pitch * t) * 0.7 + sin(TAU * pitch * 2.71 * t) * 0.3 * exp(-t * 90.0)
		var value := (body * exp(-t * 38.0) + noise * exp(-t * 160.0) * 0.8) * minf(1.0, t * 2000.0) * volume
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _stream(data)


## A small wind chime: bell partials (1, 2.76, 5.4 times each note) with a long, soft decay.
func _chime(notes: Array, seconds: float, volume: float) -> AudioStreamWAV:
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var t := float(n) / RATE
		var value := 0.0
		for k in notes.size():
			var u := t - k * 0.06
			if u < 0.0:
				continue
			var f: float = notes[k]
			value += (sin(TAU * f * u) + 0.4 * sin(TAU * f * 2.76 * u) * exp(-u * 6.0)
				+ 0.15 * sin(TAU * f * 5.4 * u) * exp(-u * 12.0)) * exp(-u * 4.0) * minf(1.0, u * 800.0)
		data.encode_s16(n * 2, int(clampf(value * volume, -1.0, 1.0) * 32767.0))
	return _stream(data)


## A kalimba run: plucked notes with a bright start that fades to a warm tone.
func _kalimba(notes: Array, step: float, seconds: float) -> AudioStreamWAV:
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var t := float(n) / RATE
		var value := 0.0
		for k in notes.size():
			var u := t - k * step
			if u < 0.0:
				continue
			var f: float = notes[k]
			value += (sin(TAU * f * u) + 0.5 * sin(TAU * f * 3.0 * u) * exp(-u * 25.0)) * exp(-u * 3.2) * minf(1.0, u * 600.0)
		data.encode_s16(n * 2, int(clampf(value * 0.12, -1.0, 1.0) * 32767.0))
	return _stream(data)


func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
