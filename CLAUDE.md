# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Godot 4.7 (Forward Plus, GDScript) 2D game, a school DDU project ("Undulaternes DDU projekt 2"). It plays like "Papers, Please" but for taxes: customers hand over tax forms (`TaxForm`, e.g. an A-SKAT/A-indkomst form), the player works out how far off the declared tax is, fills in the empty fields, and sends the customer on. The closer the answer, the higher the score. The README, code comments and in-game text are in Danish. The tax forms will also be modelled after the danish tax system.

## Running

There is no build step, linter or test suite. Open the project in the Godot 4.7 editor, or use the CLI (if `godot` is on PATH):

- Run the main scene: `godot --path .`
- Run one scene: `godot --path . "res://!DEBUG/DebugScenes/test_boards/test_boards.tscn"` (quote paths, since folders contain `!` and `&`)
- Headless script check: `godot --headless --path . --quit`

## Team conventions (from README)

- **All testing must happen in `!DEBUG/`.** Each test is a small scene under `!DEBUG/DebugScenes/<name>/` whose script builds objects in code (e.g. `test_boards`, `test_dialogue`).
- Folder layout matters. Put new code where it belongs:
  - `Classes/`: scripts for objects created many times (`Customer`, `TaxForm`, `Board`, `Dialogue`), grouped into `CustomerClasses/`, `ObjectClasses/` and `UIClasses/`.
  - `Scenes&Scripts/`: Godot scenes plus scripts for one-off things (the bell, the work place, dialogue UI scenes).
  - `Setup/`: code that runs as soon as the game starts, i.e. autoloads such as audio.
  - `Resources/`: audio, sprites, images and customer data.
- Naming: scenes and scripts use `snake_case`. Class names are PascalCase (`class_name Customer`, `CustomerData`) and their files share the class name. Resource files can be named freely.

## Architecture

- **Autoloads** (`project.godot`), called globally by name:
  - `AudioPlayer` (`Setup/AudioSetup/audio_stream_player.tscn`): a node with a `MusicPlayer` child (sound effects get a temporary `AudioStreamPlayer` each). Use `AudioPlayer.play_custom_track(path)` (looping music, no-op if already playing), `stop_music()` and `play_sound_effect(path)`. Volume: `default_bus_layout.tres` defines a `Music` bus (used by `MusicPlayer`) and an `SFX` bus (used by every player that `play_sound_effect` creates), both sending to `Master`. Any new non-music `AudioStreamPlayer` must also set `bus = &"SFX"`, or the sound-effects slider won't affect it. The user's volumes (0..1) live on the buses via `set_music_volume(v)` / `music_volume` and `set_sfx_volume(v)` / `sfx_volume` (0 mutes the bus). `save_settings()` writes both to `user://settings.cfg`, which `_ready()` loads. Fades and resets (game over, `main.gd`) use `music_player.volume_db` instead, so they don't clobber the user's setting. The sliders are `%MusicSlider` and `%SfxSlider` on the title screen.
  - `DialogueBox` (`Scenes&Scripts/UIScenes/Dialogue/dialogue_box/`): bottom dialogue panel with a speaker name.
  - `DialogueText` (`Scenes&Scripts/UIScenes/Dialogue/dialogue_text.tscn`): a floating text line, used for customer greetings.
- **Dialogue** (`Classes/UIClasses/dialogue.gd`): base `CanvasLayer` for both dialogue autoloads. `start(speaker, lines)` shows the lines, and `ui_accept` or a left click moves to the next one (the event is consumed while visible). Each scene needs a unique-name `%TextLabel`. Subclasses override `_refresh()` to update extra UI (`dialogue_box.gd` sets `%NameLabel`).
- **Classes are built in code.** Their `_init` takes arguments (`Board.new(sprite_path)`, `Customer.new("George")`), so create them with `.new(...)` + `add_child`, not by instancing a `.tscn`.
- **Customer** (`Classes/CustomerClasses/`): `Customer.new(name)` loads by convention from `res://Resources/Customers/<Name>/<name>_data.txt` and `<name>.jpg` (folder capitalised, file names lowercase). Shared customer assets are in `Resources/Customers/!CustomerResources/`. The data file is split into `[SECTION]` headers (`[DIALOGUE]`, `[GREETINGS]`, …). `CustomerData` strips blank lines and gives `read_section(key)` / `read_line(key, n)`. Clicking a customer calls `speak()` → `DialogueBox`; `want_to_speak()` shows a speech-bubble icon and calls `greet()`, which sends a random `[GREETINGS]` line to `DialogueText`.
- **Game loop** (`Scenes&Scripts/work_place/`): `work_place.tscn` holds the desk, the bell and the frame. The bell (`Scenes&Scripts/GameObjects/bell/bell.gd`) plays a sound and calls `get_parent().customer_arrive()` unless `is_serving`, so it must be a direct child of the work place. `customer_arrive()` spawns a customer (George is hardcoded for now). Placeholders mark where the arrival animation goes.
- **Board** (`Classes/ObjectClasses/Board.gd`): a draggable paper sprite in the `"boards"` group. Dropping a board onto another *clips* them (`clipped` is a two-way adjacency list), and `get_group()` returns the connected set that moves together. On mouse down, `lift()` rebuilds the clips: the board carries every board above it in draw order that overlaps it, transitively. Draw order is the child index (`bring_to_front` uses `move_child`). Hit-testing uses `size` from the texture, with `centered = false`. Board also requires a sprite_scale argument as a float, set to 1.0 if no scale change is desired.
- **TaxForm** (`Classes/ObjectClasses/TaxForm.gd`): an `@abstract` subclass of `Board` with no constructor, so `TaxForm.new()` is an error. Each concrete form (e.g. `A_Indkomst`) defines its own `_init()` that calls `super("<paper sprite path>", <scale>)` (required, because `Board._init` needs a sprite path), then calls `_build_ui()`. It implements the abstract hooks `get_form_title()`, `get_correct_total() -> float` and `_add_fields(box: VBoxContainer)` (the form's own info lines). `TaxForm` provides the rest (Template Method): `_build_ui()` (title → `_add_fields` → `answer_field` LineEdit), `validate() -> float` (correct total minus the parsed answer, overridable for multi-field forms), `_make_label()`, the static helpers `_kr()` (Danish amount formatting) and `_parse_kr()`, and the constants `FONT_SIZE`, `TITLE_FONT_SIZE` and `AM_RATE`. The answer field only accepts digits, `,` and `.` (`ANSWER_CHARS`): `_on_answer_changed()` strips everything else on `text_changed`, for both typing and paste. Note: `Board._input` consumes left clicks inside the paper, except over a visible `Control` whose `mouse_filter` isn't `IGNORE` (`_is_over_control()`): those clicks pass through to the control (e.g. the `answer_field` LineEdit). So purely visual Controls on a form (labels, containers) must use `MOUSE_FILTER_IGNORE`, or clicks on them won't start a drag.
