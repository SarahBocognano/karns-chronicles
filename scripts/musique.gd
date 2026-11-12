extends Node

## Lecteur de musique du jeu (autoload « Musique ») : fondu enchaîné d'un morceau à l'autre,
## et pendant un combat, la musique de la carte est mise de côté puis reprend là où elle en était.

## Durée des fondus, en secondes.
const FADE := 0.8
## Volume de la musique (en décibels ; 0 = volume du fichier).
const VOLUME_DB := -6.0
const SILENCE_DB := -40.0

var current: AudioStream
var _player: AudioStreamPlayer
var _fading_out: Array[AudioStreamPlayer] = []
var _saved: AudioStream
var _saved_position := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Joue `stream` en boucle, en fondu depuis le morceau en cours (rien ne change si c'est déjà lui).
func play(stream: AudioStream, fade := FADE, from_position := 0.0) -> void:
	if stream == null:
		stop(fade)
		return
	if stream == current and _player and _player.playing:
		return
	_fade_out_current(fade)
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	current = stream
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = SILENCE_DB if fade > 0.0 else VOLUME_DB
	add_child(_player)
	_player.play(from_position)
	if fade > 0.0:
		create_tween().tween_property(_player, "volume_db", VOLUME_DB, fade).set_trans(Tween.TRANS_SINE)

## Arrête la musique en fondu.
func stop(fade := FADE) -> void:
	_fade_out_current(fade)
	current = null
	_player = null

func is_playing() -> bool:
	return _player != null and _player.playing

## Début de combat : met la musique de la carte de côté et lance celle du combat.
func start_battle(stream: AudioStream) -> void:
	_saved = current
	_saved_position = _player.get_playback_position() if is_playing() else 0.0
	play(stream, 0.4)

## Fin de combat : reprend la musique de la carte là où elle en était (ou se tait s'il n'y en avait pas).
func end_battle() -> void:
	if _saved:
		play(_saved, FADE, _saved_position)
	else:
		stop(FADE)
	_saved = null

func _fade_out_current(fade: float) -> void:
	if _player == null:
		return
	var old := _player
	_fading_out.append(old)
	if fade <= 0.0:
		old.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(old, "volume_db", SILENCE_DB, fade).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_fading_out.erase(old)
		old.queue_free())
