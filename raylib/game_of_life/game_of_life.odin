package game_of_life

/*********************************************************************
                            GAME  OF  LIFE
                            (using raylib)

 This example shows a simple setup for a game with Input processing,
 updating game state and drawing game state to the screen.

 You can
 * Left-Click to bring a cell alive
 * Right-Click to kill a cell
 * Press <Space> to (un)pause the game
 * Press <Esc> to close the game

 The game starts paused.

**********************************************************************/


import time "core:time"
import rl "vendor:raylib"


Window :: struct {
	name:          cstring,
	width:         i32,
	height:        i32,
	fps:           i32,
	control_flags: rl.ConfigFlags,
}

Game :: struct {
	tick_rate: time.Duration,
	last_tick: time.Time,
	pause:     bool,
	colors:    []rl.Color,
	width:     i32,
	height:    i32,
}

World :: struct {
	width:  i32,
	height: i32,
	alive:  []u8, // Changed from storing only alive/dead to decay states
}

Cell :: struct {
	width:  f32,
	height: f32,
}

User_Input :: struct {
	left_mouse_clicked:   bool,
	right_mouse_clicked:  bool,
	toggle_pause:         bool,
	mouse_world_position: i32,
	mouse_tile_x:         i32,
	mouse_tile_y:         i32,
}


/*
 Game Of Life rules:
 * (1) A cell with 2 alive neighbors stays alive/dead
 * (2) A cell with 3 alive neighbors stays/becomes alive
 * (3) Otherwise: the cell dies/stays dead

 New Game of Life decay rules:
 * Cell States:
 *   0: Black (Dead)
 *   1: Red (Decayed)
 *   2: Orange (Decaying)
 *   3: Yellow (Decaying)
 *   4: White (Alive)
 *
 * Neighbor Influence:
 *   - Higher state neighbors influence lower state cells.
 *   - White cells treat yellow, orange, and red neighbors as black.
 *   - Yellow cells treat red neighbors as black.
 *   - Orange and Red cells treat lower states normally.
 *
 * State Transition Rules:
 *
 * For a cell to *stay* at its current state or *increase* its state:
 *
 * - White Cell (4):
 *     - 2 *white* neighbors: stays white.
 *     - Otherwise: decays to yellow.
 * - Yellow Cell (3):
 *     - 2 *yellow or higher* neighbors (yellow or white): stays yellow.
 *     - 2 or more *white* neighbors: increases to white.
 *     - Otherwise: decays to orange.
 * - Orange Cell (2):
 *     - 3 *orange or higher* neighbors (orange, yellow, or white): stays orange.
 *     - 2 or more *yellow or higher* neighbors (yellow or white): increases to yellow.
 *     - 2 or more *white* neighbors: increases to white.
 *     - Otherwise: decays to red.
 * - Red Cell (1):
 *     - 4 *red or higher* neighbors (red or higher): stays red.
 *     - 2 or more *orange or higher* neighbors (orange, yellow, or white): increases to orange.
 *     - 2 or more *yellow or higher* neighbors (yellow or white): increases to yellow.
 *     - 2 or more *white* neighbors: increases to white.
 *     - Otherwise: decays to black (0).
 * - Black Cell (0):
 *     - 3 *alive* neighbors (any state above black): becomes red.
 *     - Otherwise: stays black.
 *
 * Decay Mechanism:
 * - If none of the "stay alive/increase" conditions are met, the cell's state decreases by 1 in the next generation (every tick).
 *
 * Color Palette:
 *   - 0: Black
 *   - 1: Red
 *   - 2: Orange
 *   - 3: Yellow
 *   - 4: White
 *
 reads from world, writes into next_world
*/
update_world :: #force_inline proc(world: ^World, next_world: ^World) {
	for x: i32 = 0; x < world.width; x += 1 {
		for y: i32 = 0; y < world.height; y += 1 {
			neighbors := count_neighbors(world, x, y)
			index := y * world.width + x
			current_state := world.alive[index]
			next_state := current_state // Assume decay by default

			switch current_state {
			case 4: // White
				white_neighbors := filter_neighbors_by_state(world, x, y, 4)
				if white_neighbors == 2 {
					next_state = 4 // Stay White
				} else {
					next_state = 3 // Decay to Yellow
				}
			case 3: // Yellow
				yellow_or_higher_neighbors := filter_neighbors_by_state(world, x, y, 3) + filter_neighbors_by_state(world, x, y, 4)
				white_neighbors := filter_neighbors_by_state(world, x, y, 4)

				if yellow_or_higher_neighbors == 2 {
					next_state = 3 // Stay Yellow
				} else if white_neighbors >= 2 {
					next_state = 4 // Increase to White
				} else {
					next_state = 2 // Decay to Orange
				}
			case 2: // Orange
				orange_or_higher_neighbors := filter_neighbors_by_state(world, x, y, 2) + filter_neighbors_by_state(world, x, y, 3) + filter_neighbors_by_state(world, x, y, 4)
				yellow_or_higher_neighbors := filter_neighbors_by_state(world, x, y, 3) + filter_neighbors_by_state(world, x, y, 4)
				white_neighbors := filter_neighbors_by_state(world, x, y, 4)

				if orange_or_higher_neighbors == 3 {
					next_state = 2 // Stay Orange
				} else if yellow_or_higher_neighbors >= 2 {
					next_state = 3 // Increase to Yellow
				} else if white_neighbors >= 2 {
					next_state = 4 // Increase to White
				} else {
					next_state = 1 // Decay to Red
				}
			case 1: // Red
				red_or_higher_neighbors := filter_neighbors_by_state(world, x, y, 1) + filter_neighbors_by_state(world, x, y, 2) + filter_neighbors_by_state(world, x, y, 3) + filter_neighbors_by_state(world, x, y, 4)
				orange_or_higher_neighbors := filter_neighbors_by_state(world, x, y, 2) + filter_neighbors_by_state(world, x, y, 3) + filter_neighbors_by_state(world, x, y, 4)
				yellow_or_higher_neighbors := filter_neighbors_by_state(world, x, y, 3) + filter_neighbors_by_state(world, x, y, 4)
				white_neighbors := filter_neighbors_by_state(world, x, y, 4)

				if red_or_higher_neighbors == 4 {
					next_state = 1 // Stay Red
				} else if orange_or_higher_neighbors >= 2 {
					next_state = 2 // Increase to Orange
				} else if yellow_or_higher_neighbors >= 2 {
					next_state = 3 // Increase to Yellow
				} else if white_neighbors >= 2 {
					next_state = 4 // Increase to White
				} else {
					next_state = 0 // Decay to Black
				}
			case 0: // Black
				alive_neighbors := count_alive_neighbors(world, x, y) // Count neighbors with state > 0
				if alive_neighbors == 3 {
					next_state = 1 // Become Red (or consider starting at white?)
				} else {
					next_state = 0 // Stay Black
				}
			}
			next_world.alive[index] = u8(clamp(next_state, 0, 4)) // Ensure state stays within 0-4 range
		}
	}
}

/*
 Just a branch-less version of adding all neighbors together
*/
count_neighbors :: #force_inline proc(w: ^World, x: i32, y: i32) -> u8 {
	// our world is a torus!
	left := (x - 1) %% w.width
	right := (x + 1) %% w.width
	up := (y - 1) %% w.height
	down := (y + 1) %% w.height

	top_left := w.alive[up * w.width + left]
	top := w.alive[up * w.width + x]
	top_right := w.alive[up * w.width + right]

	mid_left := w.alive[y * w.width + left]
	mid_right := w.alive[y * w.width + right]

	bottom_left := w.alive[down * w.width + left]
	bottom := w.alive[down * w.width + x]
	bottom_right := w.alive[down * w.width + right]

	total := top_left + top + top_right + mid_left + mid_right + bottom_left + bottom + bottom_right
	return total
}

/*
 Counts neighbors with state > 0 (alive in a broad sense)
*/
count_alive_neighbors :: #force_inline proc(w: ^World, x: i32, y: i32) -> u8 {
	// our world is a torus!
	left := (x - 1) %% w.width
	right := (x + 1) %% w.width
	up := (y - 1) %% w.height
	down := (y + 1) %% w.height

	count: u8 = 0

	if w.alive[up * w.width + left] > 0 { count += 1 }
	if w.alive[up * w.width + x] > 0 { count += 1 }
	if w.alive[up * w.width + right] > 0 { count += 1 }

	if w.alive[y * w.width + left] > 0 { count += 1 }
	if w.alive[y * w.width + right] > 0 { count += 1 }

	if w.alive[down * w.width + left] > 0 { count += 1 }
	if w.alive[down * w.width + x] > 0 { count += 1 }
	if w.alive[down * w.width + right] > 0 { count += 1 }

	return count
}


/*
 Filters neighbors by state and counts how many match or exceed the given state
*/
filter_neighbors_by_state :: #force_inline proc(w: ^World, x: i32, y: i32, state: u8) -> u8 {
	// our world is a torus!
	left := (x - 1) %% w.width
	right := (x + 1) %% w.width
	up := (y - 1) %% w.height
	down := (y + 1) %% w.height

	count: u8 = 0

	if w.alive[up * w.width + left] == state { count += 1 }
	if w.alive[up * w.width + x] == state { count += 1 }
	if w.alive[up * w.width + right] == state { count += 1 }

	if w.alive[y * w.width + left] == state { count += 1 }
	if w.alive[y * w.width + right] == state { count += 1 }

	if w.alive[down * w.width + left] == state { count += 1 }
	if w.alive[down * w.width + x] == state { count += 1 }
	if w.alive[down * w.width + right] == state { count += 1 }

	return count
}

/*
 Draws all the tiles of world
*/
draw_world :: #force_inline proc(world: ^World, cell: Cell, colors: []rl.Color) {
	x, y: i32
	for y = 0; y < world.height; y += 1 {
		for x = 0; x < world.width; x += 1 {
			index := y * world.width + x
			color := colors[world.alive[index]]

			rect := rl.Rectangle {
				x      = f32(x) * cell.width,
				y      = f32(y) * cell.height,
				width  = cell.width,
				height = cell.height,
			}
			rl.DrawRectangleRec(rect, color)
		}
	}
}

/*
 Draws a yellow cell where the mouse points to
*/
draw_cursor :: proc(user_input: User_Input, cell: Cell) {

	rect := rl.Rectangle {
		x      = f32(user_input.mouse_tile_x) * cell.width,
		y      = f32(user_input.mouse_tile_y) * cell.height,
		width  = cell.width,
		height = cell.height,
	}
	rl.DrawRectangleRec(rect, rl.BLUE)
}

/**
 The user input is processed such that the rest of the code does not need
 to know anything about what the user input was. (You could process a controller here)
**/
process_user_input :: proc(user_input: ^User_Input, window: Window, world: World) {
	m_pos := rl.GetMousePosition()
	mouse_x := i32((m_pos[0] / f32(window.width)) * f32(world.width))
	mouse_y := i32((m_pos[1] / f32(window.height)) * f32(world.width))

	//Keep in bounds while painting with torus wrapping
	if user_input.left_mouse_clicked || user_input.right_mouse_clicked {
		mouse_x %%= world.width
		mouse_y %%= world.height
	}

	user_input^ = User_Input {
		left_mouse_clicked   = rl.IsMouseButtonDown(.LEFT),
		right_mouse_clicked  = rl.IsMouseButtonDown(.RIGHT),
		toggle_pause         = rl.IsKeyPressed(.SPACE),
		mouse_world_position = i32(mouse_y * world.width + mouse_x),
		mouse_tile_x         = mouse_x,
		mouse_tile_y         = mouse_y,
	}
}

main :: proc() {
	window := Window{"Game Of Life", 1024, 1024, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}

	game := Game {
		tick_rate = 60 * time.Millisecond,
		last_tick = time.now(),
		pause     = true,
		colors    = []rl.Color{rl.BLACK, rl.RED, rl.ORANGE, rl.YELLOW, rl.WHITE}, // Added more colors for decay states
		width     = 128,
		height    = 128,
	}

	world := World{game.width, game.height, make([]u8, game.width * game.height)}
	next_world := World{game.width, game.height, make([]u8, game.width * game.height)}
	defer delete(world.alive)
	defer delete(next_world.alive)

	cell := Cell {
		width  = f32(window.width) / f32(world.width),
		height = f32(window.height) / f32(world.width),
	}

	user_input: User_Input

	rl.InitWindow(window.width, window.height, window.name)
	rl.SetWindowState(window.control_flags)
	rl.SetTargetFPS(window.fps)

	// Infinite game loop. Breaks on pressing <Esc>
	for !rl.WindowShouldClose() {

		// If the user resized the window, we adjust the cell size to keep drawing over the entire window
		if rl.IsWindowResized() {
			window.width = rl.GetScreenWidth()
			window.height = rl.GetScreenHeight()

			cell.width = f32(window.width) / f32(world.width)
			cell.height = f32(window.height) / f32(world.width)
		}

		// Step 1: Process user input
		// First the user input gets translated into meaninngful attribute names
		// Then we use those to taken action based on them
		process_user_input(&user_input, window, world)

		if user_input.left_mouse_clicked {
			world.alive[user_input.mouse_world_position] = 4 // Set to White (highest state) when clicked
		}
		if user_input.right_mouse_clicked {
			world.alive[user_input.mouse_world_position] = 0 // Set to Black (dead) when right-clicked
		}
		if user_input.toggle_pause {
			game.pause = !game.pause
		}

		// Step 2: Update the world state
		// There is always a current state of the world that we read from
		// and a future state of the world that we write to
		if !game.pause && time.since(game.last_tick) > game.tick_rate {
			game.last_tick = time.now()
			update_world(&world, &next_world)

			// this is how you swap 2 variables in ODIN!
			world, next_world = next_world, world
		}

		// Step 3: Draw the world
		// The background gets cleared to a high contrast color, so it's easy
		// to see if there was any pixel missed
		rl.BeginDrawing()
		rl.ClearBackground(rl.PINK)
		draw_world(&world, cell, game.colors)
		draw_cursor(user_input, cell)

		rl.EndDrawing()
	}


}
