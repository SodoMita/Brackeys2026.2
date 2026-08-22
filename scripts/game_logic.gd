class_name GameLogic
extends RefCounted
## Pure, deterministic gameplay math for the runner.
## Kept free of nodes/timers/RNG so it can be unit-tested headless.

const LANE_COUNT := 3
const BAR_HEIGHT := 1.0
const PLAYER_RADIUS := 0.55
const START_SPEED := 16.0
const MAX_SPEED := 46.0
const ACCEL := 0.42
const MIN_GAP := 15.0
const MAX_GAP := 30.0


## Clamps a lane index into the valid range.
static func clamp_lane(lane: int) -> int:
	return clampi(lane, 0, LANE_COUNT - 1)


## Peak height reached by a jump (v^2 / 2g).
static func jump_apex(jump_velocity: float, gravity: float) -> float:
	if gravity <= 0.0 or jump_velocity <= 0.0:
		return 0.0
	return (jump_velocity * jump_velocity) / (2.0 * gravity)


## True if the player's sphere clears a bar of the given height.
static func can_clear_bar(player_y: float, bar_height: float = BAR_HEIGHT) -> bool:
	return player_y - PLAYER_RADIUS > bar_height


## Base spawn gap (world units) for the current speed, before RNG jitter.
static func next_spawn_gap(speed: float) -> float:
	return clampf(30.0 - speed * 0.28, MIN_GAP, MAX_GAP)


## Speed reached after t seconds of constant acceleration.
static func speed_after_time(t: float) -> float:
	return minf(START_SPEED + ACCEL * maxf(t, 0.0), MAX_SPEED)


## A row of pillar lanes is passable when at least one lane stays free.
static func row_is_passable(pillar_lanes: Array) -> bool:
	var blocked := {}
	for l in pillar_lanes:
		blocked[int(l)] = true
	return blocked.size() < LANE_COUNT


## Distance-based score component.
static func score_for_distance(d: float) -> int:
	return maxi(int(d), 0)
