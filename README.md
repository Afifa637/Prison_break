# Prison Break: Triple Threat Escape Challenge

Artificial Intelligence Course Project  
Godot Engine 4.2 | Multi-Agent Strategy Game

## Project Overview

**Prison Break** is a multi-agent AI competition game built in **Godot Engine 4.2**. The project explores how different artificial intelligence techniques can solve the same problem in different ways inside a dynamic prison escape environment. The game features prisoners competing to escape while avoiding guards, dogs, fire, walls, and other prison hazards.

The prison is designed as a **grid-based environment** with obstacles and competitive gameplay elements. The current project idea includes prisoners, a jailor/hunter, patrolling dogs, fire threats, walls, and locked doors, each affecting gameplay through penalties and strategic constraints. 

## Core Idea

The game demonstrates how multiple AI agents behave differently under the same prison-break scenario:

- **Rusher Red** uses **Minimax with Alpha-Beta Pruning** for aggressive, risk-taking escape decisions. 
- **Sneaky Blue** uses **A\* Pathfinding** with safety heuristics to avoid detection and choose safer paths. 
- **Gambler Green** uses **Fuzzy Logic** to balance risk and reward depending on the game state.

The presentation version also describes a setup with:
- **Rusher Red** as a Minimax-based prisoner
- **Sneaky Blue** as an A\*-based prisoner
- **Hunter / Jailor** as a Fuzzy Logic police agent

## Game World

The proposed prison environment is represented as a **20×20 grid-based prison facility** in the proposal, with zones such as cell blocks, corridors, guard rooms, and an exit gate. 

The slide deck also mentions a prison grid design with obstacles including:
- Fire
- Dog patrols
- Walls
- Locked doors 

## Agents and AI Algorithms

### 1. Rusher Red — Minimax with Alpha-Beta Pruning

Rusher Red is the aggressive escape artist. This agent uses **Minimax** to predict enemy or guard responses and chooses moves that maximize progress toward the exit. Alpha-Beta Pruning is used to reduce the number of explored branches and improve performance. 

**Behavior:**
- Takes calculated risks
- Prioritizes speed over safety
- Can force through danger if it predicts advantage
- Uses pruning to optimize search :contentReference[oaicite:9]{index=9}

### 2. Sneaky Blue — A* Pathfinding

Sneaky Blue uses **A\*** search to find efficient and safe routes through the prison. It combines actual path cost with a heuristic estimate to the exit, while also adding danger penalties for risky tiles near guards or hazards. :contentReference[oaicite:10]{index=10}

**Behavior:**
- Avoids detection
- Recalculates paths when danger changes
- Uses stealth and safe-route logic
- Waits when paths are unsafe 

### 3. Gambler Green / Hunter — Fuzzy Logic

The proposal describes **Gambler Green** as an adaptive fuzzy-logic agent that changes behavior based on danger, progress, and health.

The slide deck instead presents the **Hunter / Jailor** as the fuzzy-logic agent that decides which prisoner to chase based on:
- Distance to prisoner
- Distance to exit
- Prisoner stealth level 

This highlights the project's use of **fuzzy logic for adaptive decision-making under uncertainty**.

## Obstacles and Penalties

The prison contains multiple hazards that slow escape and increase challenge:

- **Patrolling Dogs**
- **Fire Threats**
- **Walls**
- **Locked Doors** 

Example penalties from the presentation:
- Dog patrol zone: **4s**
- Fire threat: **2s**
- Walls: **4s**
- Locked doors: **3s**

Additional gameplay penalties include:
- Capture: **-50 points**
- Health reduction
- Stealth reset
- Dog zone and camera penalties

## Actions and Mechanics

Prisoners can perform actions such as:
- Move Up / Down / Left / Right
- Sprint
- Sneak
- Wait 

The proposal expands this with:
- Standard movement
- Stealth-preserving movement
- Fast movement with penalties
- Special abilities such as Brawl, Hide, and Distraction depending on the character type 

Guard or hunter behavior includes:
- Patrol
- Pursue
- Sprint
- Capture when adjacent 

## Win Conditions

The proposal defines several possible game-ending states:
- First prisoner reaches the exit
- Time limit expires
- All prisoners are captured too many times 

The presentation simplifies this into:
- **Prisoner wins** by reaching the exit first
- **Police wins** by eliminating both prisoners

## Current Implementation Progress

The current Godot version of the project includes early gameplay features such as:
- Player movement
- Jump animation system
- Fire animation
- Dog roaming behavior
- Scene setup for multiple characters

This repository represents the practical implementation side of the broader AI game concept described in the attached proposal and presentation.

## Technology Stack

- **Engine:** Godot 4.2 
- **Language:** GDScript
- **Project Type:** 2D AI Strategy / Escape Game

## Project Structure

Example structure for the project:

```text
Prison_break/
├── scenes/
│   ├── game.tscn
│   ├── player_blue.tscn
│   ├── player_red.tscn
│   ├── dog.tscn
│   └── fire.tscn
├── scripts/
│   ├── player_blue.gd
│   ├── dog.gd
│   └── fire.gd
├── assets/
├── README.md
├── Prison_Break_Project_Proposal.docx
└── PrisonBreak.pptx
```
## Included Documents

This repository also includes the following project documents:
Project Proposal: Prison_Break_Project_Proposal.docx 
[Prison_Break_Project_Proposal.docx](https://github.com/user-attachments/files/25871974/Prison_Break_Project_Proposal.docx)
Presentation Slides: PrisonBreak.pptx 
[PrisonBreak.pptx](https://github.com/user-attachments/files/25871978/PrisonBreak.pptx)

These documents describe the design goals, AI concepts, gameplay rules, scoring, and educational objectives of the project.

## How to Run

- Open the project in Godot Engine 4.2
- Load the main scene
- Run the game from the editor

## Authors

Presented by:
- 2107067
- 2108078
- 2107087
