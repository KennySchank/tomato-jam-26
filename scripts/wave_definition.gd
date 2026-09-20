class_name WaveDefinition
extends Resource

## How long the prep phase lasts before this wave starts spawning.
@export_range(0.0, 600.0, 0.5) var prep_time: float = 30.0
## Total enemies spawned during this wave.
@export_range(1, 200) var enemy_count: int = 8
## Minimum seconds between enemy spawns during this wave.
@export_range(0.1, 10.0, 0.1) var spawn_interval_min: float = 2.0
## Maximum seconds between enemy spawns during this wave.
@export_range(0.1, 10.0, 0.1) var spawn_interval_max: float = 3.5
## Cap on enemies alive at once during this wave.
@export_range(1, 64) var max_concurrent: int = 8
## Multiplier applied to enemy movement speed during this wave.
@export_range(0.5, 3.0, 0.05) var enemy_speed_multiplier: float = 1.0
## Multiplier applied to enemy health during this wave.
@export_range(0.5, 3.0, 0.05) var enemy_health_multiplier: float = 1.0
## Multiplier applied to enemy attack frequency during this wave. Lower is faster.
@export_range(0.25, 2.0, 0.05) var enemy_attack_interval_multiplier: float = 1.0
## Enemy scenes the wave picks from when spawning.
@export var enemy_scenes: Array[PackedScene] = []
## Seeds granted to the player when this wave is defeated.
@export_range(0, 50) var reward_seeds: int = 0
