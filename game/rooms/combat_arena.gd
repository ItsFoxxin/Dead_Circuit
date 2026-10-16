class_name CombatArena
extends Node3D
## Authored room geometry/navigation and spawn markers are supplied by content.

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var navigation: NavigationRegion3D = $NavigationRegion


func enemy_spawn(index: int) -> Vector3:
	var marker: Node3D = enemy_spawns.get_child(index % enemy_spawns.get_child_count()) as Node3D
	return marker.global_position
