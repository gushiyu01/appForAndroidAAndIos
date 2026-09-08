# Gravity Maze Game Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a gravity-controlled random maze game whose entrance is always at the upper-left and exit is always at the lower-right.

**Architecture:** Keep deterministic maze generation and collision rules in a pure Dart model so they can be unit tested. Build a Flutter page that subscribes to the existing native accelerometer channel, advances ball physics on a ticker, draws the maze with a custom painter, and regenerates a new maze on restart.

**Tech Stack:** Dart, Flutter Material, CustomPainter, AnimationController, existing EventChannel motion bridge.

---

### Task 1: Random maze model

**Files:**
- Create: `lib/models/maze.dart`
- Test: `test/maze_test.dart`

1. Define cells, wall directions, randomized depth-first generation, and bounds-safe wall lookup.
2. Verify the entrance cell is upper-left, the exit cell is lower-right, and every generated maze has a route between them.
3. Verify adjacent cells agree about their shared walls.

### Task 2: Gravity maze page

**Files:**
- Create: `lib/pages/maze_game_page.dart`

1. Subscribe to `accelerometerEventStream` and smooth the X/Y gravity values.
2. Use an animation ticker to integrate velocity and position.
3. Resolve circle movement against maze walls one axis at a time.
4. Draw maze walls, entrance, exit, and ball with a custom painter.
5. Detect the lower-right goal, stop timing, and show completion feedback.
6. Add restart and pause controls; restart must generate a fresh maze.

### Task 3: Navigation and verification

**Files:**
- Modify: `lib/pages/home_page.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`
- Modify: `README.md`

1. Register the maze route and add the home-page action.
2. Update widget expectations and feature documentation.
3. Run `python tool/validate_templates.py`, `flutter analyze`, and `flutter test` where available.
