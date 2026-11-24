class_name Sfx
extends Node
## Small sounds made in code (no audio files): a soft tick for a turn, a click for a lock,
## a bell when a lantern lights and a short chord when the board is solved.

const RATE := 22050

var enabled := true
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_sounds["turn"] = _tone([880.0], 0.045, 0.22)
	_sounds["lock"] = _tone([523.25], 0.06, 0.18)
	_sounds["lantern"] = _tone([1318.5, 1975.5], 0.32, 0.16)
	_sounds["solved"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.09, 0.7)
	for i in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(name: String) -> void:
	if not enabled or not _sounds.has(name):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[name]
	player.play()


func _tone(frequencies: Array, seconds: float, volume: float) -> AudioStreamWAV:
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var t := float(n) / RATE
		var envelope := minf(1.0, t * 400.0) * exp(-t * 6.0 / seconds)
		var value := 0.0
		for f in frequencies:
			value += sin(TAU * float(f) * t)
		value = value / frequencies.size() * envelope * volume
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _stream(data)


func _arpeggio(notes: Array, step: float, length: float) -> AudioStreamWAV:
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var t := float(n) / RATE
		var value := 0.0
		for k in notes.size():
			var start := k * step
			if t >= start:
				var u := t - start
				value += sin(TAU * float(notes[k]) * u) * minf(1.0, u * 300.0) * exp(-u * 5.0)
		value *= 0.11
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _stream(data)


func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
