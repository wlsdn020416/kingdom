class_name PhysicsLayers
extends RefCounted
## 충돌 레이어 비트값. 이름은 project.godot [layer_names]와 같다.

const WATER := 1
const OBJECTS := 2
const BUILDINGS := 4
const PLAYER := 8
const ENEMIES := 16
const PASSABLE := 32  # 플레이어는 지나가고 적은 막히는 건물 (생활 건물·문, D-025)
