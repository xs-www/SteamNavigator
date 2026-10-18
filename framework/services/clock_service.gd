class_name ClockService
extends RefCounted
## Game-time helpers. Time itself lives in GameState so it participates in
## save data, transactions and reproducible tests.

const HOURS_PER_DAY := 24


static func format_time(game_time: float) -> String:
	var safe_time: float = maxf(0.0, game_time)
	var day := int(floor(safe_time / HOURS_PER_DAY)) + 1
	var hour := int(floor(fmod(safe_time, HOURS_PER_DAY)))
	var minute := int(floor(fmod(safe_time * 60.0, 60.0)))
	return "Day %d %02d:%02d" % [day, hour, minute]


static func format_duration(hours: float) -> String:
	var whole_hours := int(round(hours))
	if whole_hours < 24:
		return "%dh" % whole_hours
	var days := int(whole_hours / 24)
	var remainder := whole_hours % 24
	return "%dd %dh" % [days, remainder]


static func day_index(game_time: float) -> int:
	return int(floor(maxf(0.0, game_time) / HOURS_PER_DAY)) + 1


static func hour_of_day(game_time: float) -> float:
	return fmod(maxf(0.0, game_time), HOURS_PER_DAY)


static func add_hours(game_time: float, hours: float) -> float:
	return maxf(0.0, game_time + maxf(0.0, hours))


static func is_same_day(left: float, right: float) -> bool:
	return int(floor(left / HOURS_PER_DAY)) == int(floor(right / HOURS_PER_DAY))
