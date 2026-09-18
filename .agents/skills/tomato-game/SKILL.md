---
name: tomato-game
description: Build and maintain A Tomato for Your Gods as a small, editor-friendly Godot game. Use when implementing gameplay, scenes, UI, level content, or Godot project changes in this repository.
---

# A Tomato for Your Gods

## Core Principle

Implement the smallest complete change that solves the request. Prefer a simple, understandable solution over a generalized system, abstraction, or speculative feature.

## Scene-First Development

- Make changes in `.tscn` scenes whenever the change is representational, structural, or content-focused.
- Keep nodes, layout, transforms, resources, exported values, and connections visible and editable in the Godot editor.
- Prefer adding and configuring scene nodes over creating them at runtime.
- Use inherited or reusable scenes only when there is a real repeated component; do not introduce scene indirection for one-off content.
- Use scripts for behavior, coordination, and calculations that cannot be expressed clearly in the scene.
- Keep script-driven node creation to the minimum needed for genuinely dynamic content.
- When a scene property can replace a hard-coded script constant, expose it in the scene with `@export` and configure it there.

## Implementation Rules

- Inspect the existing scene tree and scripts before changing them.
- Preserve the current project structure and naming style unless the request requires a change.
- Avoid new managers, registries, helpers, resources, or dependencies unless the current task demonstrates a concrete need.
- Avoid compatibility layers and unused extension points.
- Keep each change localized; do not refactor neighboring code without a direct reason.
- Favor Godot-native nodes, signals, exported properties, groups, and resources before inventing custom infrastructure.
- Keep editor-authored content legible: use descriptive node names, sensible hierarchy, and explicit scene properties.
- Do not encode content in opaque strings or large generated data when the same result can be edited as scene nodes or resources.

## Verification

- Validate changed GDScript with the Godot script checker or editor diagnostics.
- Run the affected scene when practical and check the behavior relevant to the request.
- For scene-only changes, inspect the saved scene tree and perform a focused playtest rather than adding unnecessary automated machinery.
- Report verification results and any unverified edge cases.

## Scope

This skill supplements the repository and workspace instructions. Follow higher-priority instructions when they conflict. The current project uses Godot 4.7, keeps scenes under `res://scenes/`, and runs `res://scenes/main.tscn` as its main scene.
