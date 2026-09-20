extends Node

## In-memory, session-scoped stats. Kept alive as long as the Godot process is
## running (i.e. across restarts of the run itself), wiped when the game is
## rebuilt / relaunched. No disk persistence by design.
##
## Wiring:
##   - `record_tomato_deposit(delta)` → called from `GameState._recount_tomatoes`
##     whenever the altar total ticks up.
##   - `record_boon_collected()` → called from `RoundEnd._on_boon_chosen`.
##   - `record_round_completed()` → called from `main.gd._on_round_end_closed`
##     (a round ends successfully when the player dismisses the boon screen).
##   - `record_death()` → called from `main.gd._on_game_lost` right before the
##     game-over screen is shown. Returns a `DeathReport` describing the run so
##     the UI can display totals and any record-broken message.

signal stats_changed
signal record_broken(previous_best: int, new_best: int)

## Cumulative counters across every run in this session.
var lifetime_tomatoes_collected: int = 0
var lifetime_boons_collected: int = 0
var lifetime_rounds_completed: int = 0
var deaths: int = 0

## Single-run best.
var best_tomatoes_in_run: int = 0

## Counters for the run currently in progress. Reset on `record_death()` so the
## next run starts fresh.
var current_run_tomatoes: int = 0
var current_run_boons: int = 0
var current_run_rounds: int = 0

## Snapshot returned by `record_death()` so the game-over screen doesn't have
## to reach into the tracker's mutable state to display the run summary.
class DeathReport:
	var tomatoes_this_run: int = 0
	var boons_this_run: int = 0
	var rounds_this_run: int = 0
	var beat_record: bool = false
	var previous_best: int = 0
	var new_best: int = 0
	var deaths_total: int = 0
	var lifetime_tomatoes: int = 0
	var lifetime_boons: int = 0
	var lifetime_rounds: int = 0

func record_tomato_deposit(amount: int) -> void:
	if amount <= 0:
		return
	current_run_tomatoes += amount
	lifetime_tomatoes_collected += amount
	stats_changed.emit()

func record_boon_collected() -> void:
	current_run_boons += 1
	lifetime_boons_collected += 1
	stats_changed.emit()

func record_round_completed() -> void:
	current_run_rounds += 1
	lifetime_rounds_completed += 1
	stats_changed.emit()

## Finalize the current run. Bumps the death counter, updates the personal
## best if beaten, resets the per-run counters, and returns a snapshot.
func record_death() -> DeathReport:
	deaths += 1
	var report := DeathReport.new()
	report.tomatoes_this_run = current_run_tomatoes
	report.boons_this_run = current_run_boons
	report.rounds_this_run = current_run_rounds
	report.previous_best = best_tomatoes_in_run
	report.beat_record = current_run_tomatoes > best_tomatoes_in_run and current_run_tomatoes > 0
	if report.beat_record:
		best_tomatoes_in_run = current_run_tomatoes
		record_broken.emit(report.previous_best, best_tomatoes_in_run)
	report.new_best = best_tomatoes_in_run
	report.deaths_total = deaths
	report.lifetime_tomatoes = lifetime_tomatoes_collected
	report.lifetime_boons = lifetime_boons_collected
	report.lifetime_rounds = lifetime_rounds_completed
	current_run_tomatoes = 0
	current_run_boons = 0
	current_run_rounds = 0
	stats_changed.emit()
	return report
