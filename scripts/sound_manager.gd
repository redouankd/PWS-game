extends Node

const MAX_PLAYERS := 8

var _pool: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = [AudioStreamPlayer.new(), AudioStreamPlayer.new()]
var _active_music_index: int = 0

func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	for p in _music_players:
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	# all busy, steal the first one
	_pool[0].stream = stream
	_pool[0].volume_db = volume_db
	_pool[0].play()

func play_music(stream: AudioStream, fade_time: float = 1.0, loop: bool = true) -> void:
	if stream == null:
		return
	var next_index := 1 - _active_music_index
	var old_player := _music_players[_active_music_index]
	var new_player := _music_players[next_index]

	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_player, "volume_db", 0.0, fade_time)
	tween.tween_property(old_player, "volume_db", -80.0, fade_time)
	tween.chain().tween_callback(old_player.stop)

	_active_music_index = next_index

func stop_music(fade_time: float = 1.0) -> void:
	var p := _music_players[_active_music_index]
	var tween := create_tween()
	tween.tween_property(p, "volume_db", -80.0, fade_time)
	tween.tween_callback(p.stop)
