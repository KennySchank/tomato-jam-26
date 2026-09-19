class_name WaveManager
extends Node

signal prep_phase_started(wave_index: int, prep_time: float)
signal prep_time_changed(seconds_remaining: float)
signal wave_started(wave_index: int, total_enemies: int)
signal wave_progress_changed(spawned: int, alive: int, total: int)
signal wave_ended(wave_index: int, wave: WaveDefinition)
signal all_waves_completed
signal game_lost
signal game_won
signal spawn_requested(enemy_scene: PackedScene)

enum Phase { IDLE, PREPARING, ACTIVE, COMPLETED, LOST }

## Waves executed in order. Edit each wave's fields in the inspector.
@export var waves: Array[WaveDefinition] = []
## Group name used to count enemies still alive.
@export var enemies_group: StringName = &"enemies"
## Start the first prep phase automatically on _ready.
@export var auto_start: bool = true
## Input action pressed during prep to skip straight to the wave.
@export var skip_prep_action: StringName = &"ui_accept"

@export_group("Endless Mode")
## After the authored waves complete, keep spawning procedurally scaled waves.
@export var endless_mode: bool = false
## Prep time used for every endless wave.
@export_range(0.0, 120.0, 0.5) var endless_prep_time: float = 20.0
## Extra enemies added per endless wave beyond the last authored one.
@export_range(0, 40) var endless_enemy_step: int = 4
## Extra concurrent enemies allowed per endless wave.
@export_range(0, 20) var endless_concurrent_step: int = 1
## Spawn interval is multiplied by this factor each endless wave (min & max).
@export_range(0.5, 1.0, 0.01) var endless_spawn_interval_factor: float = 0.92
## Lower bound clamp for endless spawn interval min.
@export_range(0.1, 5.0, 0.1) var endless_min_spawn_interval: float = 0.4

var phase: int = Phase.IDLE
var current_wave_index: int = -1
var current_wave: WaveDefinition

var _prep_time_remaining: float = 0.0
var _spawn_cooldown: float = 0.0
var _enemies_spawned: int = 0

func _ready() -> void:
	if auto_start:
		start_next_wave_prep.call_deferred()

## Advance to the next wave's prep phase, or complete if none remain.
func start_next_wave_prep() -> void:
	current_wave_index += 1
	current_wave = _wave_for_index(current_wave_index)
	if current_wave == null:
		phase = Phase.COMPLETED
		all_waves_completed.emit()
		return
	phase = Phase.PREPARING
	_prep_time_remaining = current_wave.prep_time
	_enemies_spawned = 0
	_spawn_cooldown = 0.0
	prep_phase_started.emit(current_wave_index, current_wave.prep_time)
	prep_time_changed.emit(_prep_time_remaining)

## Skip the remainder of the current prep phase (e.g. bound to a "Ready" button).
func skip_prep() -> void:
	if phase == Phase.PREPARING:
		_prep_time_remaining = 0.0

## End the run in a loss state; the manager stops spawning.
func trigger_loss() -> void:
	if phase == Phase.LOST or phase == Phase.COMPLETED:
		return
	phase = Phase.LOST
	game_lost.emit()

## End the run in a win state; the manager stops spawning.
func trigger_win() -> void:
	if phase == Phase.COMPLETED or phase == Phase.LOST:
		return
	phase = Phase.COMPLETED
	game_won.emit()

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PREPARING:
		return
	if event.is_action_pressed(skip_prep_action):
		skip_prep()

func _process(delta: float) -> void:
	match phase:
		Phase.PREPARING:
			_tick_prep(delta)
		Phase.ACTIVE:
			_tick_active(delta)

func _tick_prep(delta: float) -> void:
	_prep_time_remaining = maxf(0.0, _prep_time_remaining - delta)
	prep_time_changed.emit(_prep_time_remaining)
	if _prep_time_remaining <= 0.0:
		_begin_active_phase()

func _begin_active_phase() -> void:
	phase = Phase.ACTIVE
	wave_started.emit(current_wave_index, current_wave.enemy_count)
	wave_progress_changed.emit(0, 0, current_wave.enemy_count)

func _tick_active(delta: float) -> void:
	var alive := _alive_enemy_count()
	if _enemies_spawned < current_wave.enemy_count:
		_spawn_cooldown = maxf(0.0, _spawn_cooldown - delta)
		if _spawn_cooldown <= 0.0 and alive < current_wave.max_concurrent:
			if _emit_spawn_request(current_wave):
				_enemies_spawned += 1
				_spawn_cooldown = randf_range(current_wave.spawn_interval_min, current_wave.spawn_interval_max)
				wave_progress_changed.emit(_enemies_spawned, alive + 1, current_wave.enemy_count)
	elif alive == 0:
		_end_wave()

func _emit_spawn_request(wave: WaveDefinition) -> bool:
	if wave.enemy_scenes.is_empty():
		push_warning("Wave %d has no enemy_scenes configured." % current_wave_index)
		return false
	var scene: PackedScene = wave.enemy_scenes.pick_random()
	spawn_requested.emit(scene)
	return true

func _end_wave() -> void:
	var completed_index := current_wave_index
	var completed_wave := current_wave
	wave_ended.emit(completed_index, completed_wave)
	start_next_wave_prep()

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group(enemies_group).size()

func _wave_for_index(index: int) -> WaveDefinition:
	if index < waves.size():
		return waves[index]
	if not endless_mode or waves.is_empty():
		return null
	return _generate_endless_wave(index)

func _generate_endless_wave(index: int) -> WaveDefinition:
	var base: WaveDefinition = waves[waves.size() - 1]
	var steps: int = index - waves.size() + 1
	var generated := WaveDefinition.new()
	generated.prep_time = endless_prep_time
	generated.enemy_count = base.enemy_count + endless_enemy_step * steps
	generated.max_concurrent = base.max_concurrent + endless_concurrent_step * steps
	var factor: float = pow(endless_spawn_interval_factor, steps)
	generated.spawn_interval_min = maxf(endless_min_spawn_interval, base.spawn_interval_min * factor)
	generated.spawn_interval_max = maxf(generated.spawn_interval_min + 0.25, base.spawn_interval_max * factor)
	generated.enemy_scenes = base.enemy_scenes
	generated.reward_seeds = base.reward_seeds
	return generated
