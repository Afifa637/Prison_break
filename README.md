# 🔒 Prison Break — Multi-Agent AI Simulation

> **Course:** Artificial Intelligence Laboratory (CSE 3209)
> **Institution:** Khulna University of Engineering & Technology (KUET)
> **Submitted To:** Mehrab Hossain Opi & Waliul Islam Sumon, Lecturers, Dept. of CSE
> **Submission Date:** 27 April, 2026 | **Year:** 3rd | **Term:** 2nd | **Lab Group:** B1

---

## 👥 Work Distribution

| Student Roll | Agent | AI Algorithm |
|:---:|:---:|:---:|
| **2107067** | 🔵 Blue Prisoner *(SneakyBlue)* | **Monte Carlo Tree Search (MCTS)** |
| **2107078** | 🔴 Red Prisoner *(RusherRed)* | **Minimax with Alpha-Beta Pruning** |
| **2107087** | 👮 Police/Hunter | **Fuzzy Logic Inference System + A\* Pathfinding** |

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Agent Design and AI Algorithms](#3-agent-design-and-ai-algorithms)
4. [Game Environment](#4-game-environment)
5. [Scoring and Performance Evaluation](#5-scoring-and-performance-evaluation)
6. [AI Decision Visualization](#6-ai-decision-visualization)
7. [Project Structure](#7-project-structure)
8. [How to Run](#8-how-to-run)

---

## 1. Project Overview

**Prison Break** is a Godot 4-based multi-agent artificial intelligence simulation set inside a prison escape scenario. The project places three distinct AI techniques — Fuzzy Logic, Minimax with Alpha-Beta Pruning, and Monte Carlo Tree Search — into the same adversarial environment so their decision-making can be directly observed and compared.

- The **Police/Hunter** is the defensive agent, using Fuzzy Logic to decide whether to chase, intercept, investigate, or patrol, based on uncertain real-time signals.
- **RusherRed** (the Red Prisoner) uses Minimax with Alpha-Beta Pruning to plan escape moves adversarially against the police.
- **SneakyBlue** (the Blue Prisoner) uses Monte Carlo Tree Search to estimate future escape paths through random rollout simulations.

The environment is rich with obstacles: walls, barriers, fire hazards, CCTV cameras, a dog NPC, rotating exits, and a full scoring/replay system. This makes it a genuine AI decision-visualization platform, not merely a visual game.

---

## 2. System Architecture

The project uses a **centralized simulation architecture** driven by a signal/event bus (`EventBus`). All agents, systems, and UI components communicate through emitted events rather than direct references.

```
Game Scene
│
├── Tick Clock (0.25s ticks, 60s match)
│
└── Simulation Loop
    ├── Grid Engine / Cost Map / Danger Map
    ├── EventBus (signal/event-driven design)
    ├── Scoring System
    ├── AI Decision Recorder
    │
    ├── Police/Hunter ── Fuzzy Logic Controller
    ├── Red Prisoner  ── Minimax Controller
    ├── Blue Prisoner ── MCTS Controller
    ├── Dog NPC + CCTV System
    │
    └── HUD, Overlays, Result Screen, Replay, Benchmark
```

Each simulation tick follows this order:

1. Update perception, CCTV visibility, and alert decay
2. Rebuild danger and cost maps
3. Query each AI controller for its decision
4. Resolve movement, sprint, wait, interact, and ability actions
5. Update dog, fire, doors, status effects, and cooldowns
6. Rebuild post-move danger and cost maps
7. Apply periodic scoring tick
8. Check escape, capture, fire elimination, and timeout
9. Record metrics, AI analysis data, and replay snapshot
10. Update HUD and overlays

---

## 3. Agent Design and AI Algorithms

### 3.1 Police/Hunter — Fuzzy Logic AI

**File:** `ai/fuzzy_controller.gd`, `ai/fuzzy_config.gd` | **Implemented by:** Roll 2107087

The Police/Hunter is the defensive AI. Fuzzy logic is used because its decisions depend on uncertain, continuously changing signals — a hard if-else system would cause unnatural snapping between behaviours.

#### Fuzzy Inputs

| Input | Membership Sets | Meaning |
|---|---|---|
| Police-prisoner distance | Near, Medium, Far | Proximity determines chase urgency |
| Alert level | Suspicious, Alarmed | How alerted the police currently is |
| Exit threat / escape urgency | Low, Medium, High | How close the prisoner is to escaping |
| CCTV confidence | Weak, Medium, Strong | How reliable the camera signal is |

#### Distance Membership Thresholds

| Set | Full Membership | Zero Membership |
|---|---|---|
| Near | ≤ 3.0 tiles | 5.5 tiles |
| Medium | Peaks at 7.0 tiles | Starts 3.5, ends 11.0 |
| Far | Starts at 7.0 tiles | Full at 12.0 |

#### Target Priority Formula

Before selecting a behaviour, the fuzzy controller scores each prisoner to decide who to target:

```
target_priority =
    capture_opportunity
  + exit_threat
  + visibility_confidence × 2.0
  + cctv_confidence × 1.7
  + low_stealth_bonus
  - police_distance_cost
  - target_switch_penalty
```

#### Rule Base

| Rule Component | Behaviour Supported |
|---|---|
| `near_mu × w_chase` | Chase — prisoner is close |
| `medium_mu × alarmed_mu` | Chase — medium distance and alarmed |
| `exit_high_mu` | Intercept — prisoner near active exit |
| `cctv_strong_mu` | Chase or Intercept — reliable camera info |
| `cctv_medium_mu` | Investigate — signal is useful but uncertain |
| `far_mu × suspicious_mu` | Investigate — far but suspicious |
| `far_mu × (1.0 - alert_level)` | Patrol — far and calm |

#### Defuzzification

**Winner-takes-all**: the behaviour with the highest accumulated score wins. Centroid defuzzification is not used because the output is a discrete tactical action, not a continuous value.

```
Possible final behaviours:  Chase | Intercept | Investigate | Patrol
```

#### Behaviour → Movement Mapping

| Behaviour | Movement Target |
|---|---|
| Chase | Prisoner's current position or nearby capture approach tile |
| Intercept | A tile ahead on the prisoner's path toward the active exit |
| Investigate | Last seen position or CCTV-hinted position |
| Patrol | Strategic guard tile near exit or likely escape route |

Movement is executed by A\* pathfinding (shared utility in `ai/ai_controller.gd`).

---

### 3.2 Red Prisoner — Minimax with Alpha-Beta Pruning

**File:** `ai/minimax_controller.gd`, `ai/minimax_config.gd` | **Implemented by:** Roll 2107078 | **Agent:** RusherRed

The Red prisoner is a rusher-style escape agent. It treats the Police/Hunter as an adversarial opponent and uses Minimax to plan the move that maximizes escape value while the police tries to minimize it. Alpha-Beta pruning removes branches that cannot affect the final decision.

| Feature | Description |
|---|---|
| Algorithm | Minimax with Alpha-Beta Pruning |
| Role | Maximizing player (escape value) |
| Opponent model | Police/Hunter as minimizing player |
| Strength | Deterministic strategic planning against opponent model |
| Weakness | Depends on search depth and heuristic quality |

#### Evaluation Function

```
score =
    w_exit   × (−distance_to_exit)             # Progress toward active exit
  + w_risk   × (−danger_cost)                  # Avoid dangerous tiles
  + w_opp    × (−1 / max(dist_to_police, 1))   # Stay away from police
  + w_stam   × stamina_ratio                   # Preserve stamina
  − guard_penalty                              # Penalise police proximity
  − fire_penalty                               # Penalise fire tiles
  − wall_penalty                               # Penalise wall adjacency
```

#### Alpha-Beta Pruning

```
Red root (maximizer)
├── Red move A
│   ├── Police response A1 → score
│   └── Police response A2 → score
├── Red move B
│   ├── Police response B1 → score
│   └── Police response B2 → PRUNED (β ≤ α)
└── Red move C
    └── Police response C1 → score
```

When `beta ≤ alpha`, the remaining branch is pruned, allowing deeper search within real-time tick limits.

---

### 3.3 Blue Prisoner — Monte Carlo Tree Search

**File:** `ai/mcts_controller.gd`, `ai/mcts_config.gd` | **Implemented by:** Roll 2107067 | **Agent:** SneakyBlue

The Blue prisoner is a stealth-oriented escape agent. Exact future prediction is expensive, so MCTS estimates move quality through random rollout simulations rather than exhaustive tree expansion.

| Feature | Description |
|---|---|
| Algorithm | Monte Carlo Tree Search (MCTS) |
| Goal | Escape while avoiding Police/Hunter, dog, CCTV, and fire |
| Strength | Simulation-based planning under uncertainty |
| Weakness | Depends on rollout count and reward design |

#### Four Phases of MCTS

```
1. Selection       → Choose a promising node using UCT score
2. Expansion       → Add one or more child nodes (new candidate moves)
3. Simulation      → Play a random rollout from the expanded node
4. Backpropagation → Update visit counts and rewards up the tree
```

#### UCT Formula

```
UCT = average_reward + C × √(ln(parent_visits) / child_visits)
```

- `average_reward` — exploitation: favour moves that scored well before
- `C × √(...)` — exploration: give less-visited moves a chance
- `C` — exploration constant controlling the balance between the two

Rollout scoring considers: escape progress, distance to exit, police safety, dog/CCTV/fire danger, stamina cost, active exit rotation, and survival. Simulated police movement is included so Blue does not over-optimistically plan through the police position.

---

### 3.4 Shared Pathfinding — A\* and BFS

**File:** `ai/ai_controller.gd` | **Implemented by:** Roll 2107087

All three agents rely on a shared `AIController` base class for movement execution:

- **A\* pathfinding** (`grid.astar(start, goal, cost_map)`) — computes tile-by-tile paths toward each agent's current strategic target. The cost map incorporates danger values so agents naturally prefer safer routes.
- **BFS fallback** (`bfs_fallback()`) — when A\* fails, BFS finds the farthest reachable tile from police positions as a safe-positioning fallback for prisoners.
- **BFS closest-target fallback** (`bfs_closest_target_fallback()`) — finds the closest reachable target from a set of candidates, used by the police when primary pathfinding fails.
- **Oscillation avoidance** — a position history buffer (`HISTORY_SIZE = 8`) prevents agents from bouncing endlessly between two tiles.

---

### 3.5 Dog NPC

**File:** `gameplay/dog_npc.gd`

The dog is a mobile environmental threat controlled by a state machine. When it spots a prisoner, the Police/Hunter alert level rises. When it latches (Manhattan distance ≤ 1), it applies a `dog_pinned` status effect and triggers a dog-assist scoring event.

| State | Behaviour |
|---|---|
| Patrol | Follows patrol waypoints |
| Alert | Detected suspicious noise or proximity |
| Sniff | Investigates nearby area |
| Chase | Moves toward the prisoner |
| Latched | Catches and slows the prisoner |
| Release Cooldown | Resets and returns to patrol |

---

## 4. Game Environment

The entire environment is a **discrete tile grid**. All agents store grid positions and move by selecting neighbouring walkable cells. This shared coordinate model allows all AI techniques and supporting systems to operate consistently.

| Element | Gameplay Effect | AI Effect |
|---|---|---|
| Wall / Boundary | Blocks movement, shapes corridors | Forces route planning via A\* |
| Door / Barrier | Restricts or delays paths | Changes available actions and path cost |
| Fire Hazard | Creates danger, penalties, or elimination pressure | Discourages risky paths; seeds danger map |
| CCTV | Detects prisoners in range | Increases police information and alert level |
| Dog | Mobile patrol threat | Changes prisoner safety zones and police alert |
| Active Exit | The prisoner's escape objective | Drives prisoner goals and police interception |
| Decoy / Inactive Exit | Non-goal exit | Can mislead path choices or add route penalties |

**CCTV detection flow:**
```
Prisoner enters CCTV range
  → Visibility check (range + field-of-view + raycast)
  → Prisoner receives detected status effect + score penalty
  → Police/Hunter alert increases
  → Fuzzy target priority and behaviour scores recalculated
```

**Capture and escape rules:**
```
Capture:  Manhattan distance (police, prisoner) ≤ 1  AND  capture_cooldown == 0
          → 3 captures = elimination; otherwise prisoner respawns
Escape:   Prisoner reaches the active exit → inactive, escape bonus awarded
Timeout:  60-second timer expires → remaining prisoners timed out
```

**Outcome categories:**

| Outcome | Condition |
|---|---|
| **Prisoners Win** | Both prisoners escape |
| **Police Wins** | All prisoners captured, eliminated, or failed to escape |
| **Partial Escape** | At least one prisoner escapes, but not all |
| **Timeout** | Match ends before full resolution |

---

## 5. Scoring and Performance Evaluation

**File:** `core/scoring_system.gd`, `data/scoring_config.tres`

The scoring system listens to simulation events via EventBus and converts them into raw scores and performance percentages (0–100%).

| Event | Prisoner Score Effect | Police Score Effect |
|---|---|---|
| Prisoner escapes | Large escape bonus | Escape-allowed penalty |
| Police captures prisoner | Capture penalty | Capture bonus + repeat bonus |
| CCTV detects prisoner | Detection penalty | CCTV assist opportunity |
| Dog detects / engages | Zone or engagement penalty | Dog assist opportunity |
| Fire contact / elimination | Fire penalty | Fire assist opportunity |
| Timeout | Timeout penalty | Containment advantage |
| Patrol coverage | — | Patrol coverage bonus |
| Partial escape | Mixed result | Mixed containment and escape penalty |

---

## 6. AI Decision Visualization

### Live HUD (`ui/hud_root.gd`)
Displays during the match: match timer, per-agent status panels (score, stamina, performance %, AI mode), live Fuzzy Logic behaviour bars (Chase / Intercept / Investigate / Patrol), threat level gauge, CCTV feed panels, and a timestamped incident log.

### Decision Overlays
Live overlays drawn on the grid: candidate A\* paths, danger heatmap, CCTV and police vision cones, and planned route paths.

### Result Screen (`scenes/results_screen.gd`)
Post-match screen with final outcome banner, per-agent ranking cards, and a link to the AI Analysis page.

### AI Analysis Page
The primary educational screen — shows the full reasoning trace for each agent after the match:

| Agent | What Is Shown |
|---|---|
| Police/Hunter (Fuzzy) | Target priority scores; behaviour scores for Chase, Intercept, Investigate, Patrol; full decision timeline |
| Red Prisoner (Minimax) | Minimax tree with candidate moves, police response branches, pruning markers, and evaluation scores |
| Blue Prisoner (MCTS) | MCTS tree with visit counts (N), average rewards (Q), UCT scores, and rollout path samples |

### Replay and Benchmark Tools (`tools/`)

| Tool | Purpose |
|---|---|
| `replay_exporter.gd` | Exports match snapshots to JSON |
| `replay_importer.gd` | Imports and replays saved JSON files |
| `benchmark_runner.gd` | Runs multiple headless simulations, outputs CSV/JSON statistics |
| `step_debugger.gd` | Pauses execution tick-by-tick for AI decision debugging |

---

## 7. Project Structure

```
Prison_break-feat-Afifa/
│
├── project.godot               # Godot config, autoloads, input actions, viewport
│
├── ai/                         # All AI controllers and configs
│   ├── ai_controller.gd        # Shared A* pathfinding + BFS + oscillation avoidance
│   ├── fuzzy_controller.gd     # Police/Hunter fuzzy logic inference system
│   ├── fuzzy_config.gd/.tres   # Fuzzy membership thresholds and weights
│   ├── minimax_controller.gd   # Red prisoner Minimax + Alpha-Beta pruning
│   ├── minimax_config.gd/.tres # Minimax depth and weight config
│   ├── mcts_controller.gd      # Blue prisoner MCTS (Selection/Expansion/Rollout/BP)
│   └── mcts_config.gd/.tres    # MCTS rollout count and UCT constant config
│
├── autoloads/                  # Global singletons
│   ├── event_bus.gd            # Central signal hub for all simulation events
│   ├── sim_random.gd           # Seeded random number service
│   ├── sound_manager.gd        # Audio management
│   └── user_settings.gd        # Persistent user preferences
│
├── core/                       # Core simulation systems
│   ├── simulation_loop.gd      # Main tick-based simulation coordinator
│   ├── scoring_system.gd       # Event-driven score and performance tracking
│   ├── grid_engine.gd          # Tile grid, neighbour generation, A* implementation
│   ├── cost_map.gd             # Danger-weighted path cost layer
│   ├── danger_map.gd           # Danger heatmap (fire, dog, police zones)
│   ├── ai_decision_recorder.gd # Records per-tick AI decisions for analysis/replay
│   └── tick_clock.gd           # 0.25s tick timer and 60s match timer
│
├── data/                       # Configuration resources (.tres)
│   ├── ai/                     # AI config resources (fuzzy, minimax, mcts)
│   ├── agents/                 # Agent stat resources (police, red, blue)
│   ├── simulation_config.tres
│   └── scoring_config.tres
│
├── gameplay/                   # Agents, NPC, abilities, status effects, hazards
│   ├── agent.gd                # Base agent class (movement, stamina, status)
│   ├── police_hunter.gd        # Police/Hunter agent node
│   ├── rusher_red.gd           # Red prisoner agent node
│   ├── sneaky_blue.gd          # Blue prisoner agent node
│   ├── dog_npc.gd              # Dog state machine (Patrol/Alert/Sniff/Chase/Latch)
│   ├── fire_hazard.gd          # Fire tile logic and danger seeding
│   ├── door_interactable.gd    # Door/barrier interaction logic
│   ├── abilities/              # Agent ability scripts (sprint, hide, brawl, etc.)
│   └── status_effects/         # Status effect scripts (detected, pinned, stunned, etc.)
│
├── scenes/                     # Godot scene files and controllers
│   ├── game.gd / game.tscn     # Main game scene
│   ├── main.gd / main.tscn     # Scene manager and entry point
│   ├── title_screen.gd         # Title/start screen
│   ├── intro_screen.gd         # Intro video screen
│   └── results_screen.gd       # Post-match result and AI analysis screen
│
├── ui/                         # HUD and overlay scripts
│   ├── hud_root.gd             # Master HUD (timer, agent panels, incident log)
│   ├── decision_overlay.gd     # Live AI path/decision overlays on grid
│   ├── danger_heatmap_overlay.gd
│   ├── vision_overlay.gd
│   └── pause_overlay.gd
│
├── world/                      # Map and grid rendering
│   ├── map_generator.gd        # Procedural prison map generation
│   ├── grid_renderer.gd        # Visual tile rendering
│   └── exit_rotator.gd         # Active exit rotation logic
│
├── tools/                      # Development and analysis tools
│   ├── benchmark_runner.gd
│   ├── replay_exporter.gd
│   ├── replay_importer.gd
│   └── step_debugger.gd
│
├── assets/                     # Visual, audio, and portrait assets
├── prison-break-ui.html        # HTML UI prototype (interface reference)
└── LICENSE
```

---

## 8. How to Run

**Requirements:** [Godot 4](https://godotengine.org/download) (version 4.x) — no external dependencies.

1. Extract the project folder.
2. Open **Godot 4**, click **Import**, and select the `project.godot` file.
3. Press **F5** to run. The intro screen plays, then the title screen — press **Play** to start.

**In-game shortcuts:**

| Key | Action |
|---|---|
| `Esc` / `T` | Pause overlay |
| `R` | Replay (on result screen) |
| `A` | Open AI Analysis page (on result screen) |
| `1` / `2` / `3` | Switch AI Analysis tabs (Fuzzy / MCTS / Minimax) |

**Headless benchmark:**
```bash
godot --headless --script tools/run_benchmark_headless.gd
```
Output (CSV/JSON) is written to the Godot user data directory.

---

*Developed as part of the Artificial Intelligence Laboratory (CSE 3209) — Khulna University of Engineering & Technology.*
