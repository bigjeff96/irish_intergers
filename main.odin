package irish_integers

import "core:fmt"
import rl "vendor:raylib"
import "core:c"
import "core:math/rand"
import "core:math"
WINDOW_HEIGHT :: 700
WINDOW_WIDTH :: 1200
FONT_SIZE :: 69
FONT_SPACING :: 5
BOARD_SIZE :: 500

board := rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
square_length: f32 = BOARD_SIZE / 4

main :: proc() {
    using rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "lul")
    defer CloseWindow()

    SetTargetFPS(60)
    for !WindowShouldClose() {
        if IsKeyPressed(.Q) do break
        render_game()
        free_all(context.temp_allocator)
    }
}

render_game :: proc() {
    using rl
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(RAYWHITE)
    origine := Vector2{board.x, board.y}
    // draw board and line separators
    defer {
        // board
        DrawRectangleLinesEx(board, 6, BLACK)
        // vertical
        for i in 0 ..< 3 {
            x: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {x, 0}
            end := origine + {x, board.height}
            DrawLineEx(start, end, 3, BLACK)
        }
        // horizontal
        for i in 0 ..< 3 {
            y: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {0, y}
            end := origine + {board.width, y}
            DrawLineEx(start, end, 3, BLACK)
        }
	// numbers
	for i in 0 ..< 4 {
            for j in 0 ..< 4 {
		number := random_number()
		draw_number_in_cell(number, {i, j})
            }
	}
    }

    mouse_position := GetMousePosition()
    for i in 0 ..< 4 {
        for j in 0 ..< 4 {
	    box_rect := get_cell_rect({i,j})
	    collison := CheckCollisionPointRec(mouse_position, box_rect)
            if collison && IsMouseButtonUp(.LEFT) do DrawRectangleRec(box_rect, RED)
            else if collison do DrawRectangleRec(box_rect, GREEN)
	    if collison {
		fmt.printf("%v\r",[?]int{i,j})
	    }
        }
    }
}

Rectangle_cint :: struct {
    x, y, width, height: c.int,
}

Board_matrix :: distinct [4][4]int

rect_float_to_int :: #force_inline proc(rect: rl.Rectangle) -> Rectangle_cint {
    return(
        Rectangle_cint{
            x = auto_cast rect.x,
            y = auto_cast rect.y,
            width = auto_cast rect.width,
            height = auto_cast rect.height,
        } \
    )
}

draw_number_in_cell :: proc(
    number: int,
    cell_coords: [2]int,
    board: rl.Rectangle = board,
    square_length: f32 = square_length,
) {
    assert(number <= 20 && number > 0)
    assert(cell_coords[0] < 4 && cell_coords[0] >= 0)
    assert(cell_coords[1] < 4 && cell_coords[1] >= 0)
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, FONT_SIZE, FONT_SPACING)
    box_rect := get_cell_rect(cell_coords)
    DrawTextEx(
        font,
        text,
	{box_rect.x, box_rect.y} +
        {(square_length - measure.x) / 2, (square_length - measure.y) / 2 + 5},
        FONT_SIZE,
        FONT_SPACING,
        BLACK,
    )
}

random_number :: #force_inline proc(lo := 1, hi := 20, r: ^rand.Rand = nil) -> int {
    number_float := rand.float64_range(1, 20)
    return int(number_float + 0.5)
}

get_cell_rect :: proc(cell_coords: [2]int, board := board, square_length := square_length) -> rl.Rectangle {
    assert(cell_coords[0] < 4 && cell_coords[0] >= 0)
    assert(cell_coords[1] < 4 && cell_coords[1] >= 0)
    return rl.Rectangle {
	x      = board.x + square_length * auto_cast cell_coords.y,
        y      = board.y + square_length * auto_cast cell_coords.x,
        width  = square_length,
        height = square_length,
    }
}

mouse_cell_colllision :: proc(mouse_position: rl.Vector2, cell_coords: [2]int, board := board, square_length := square_length) -> bool {
    assert(cell_coords[0] < 4 && cell_coords[0] >= 0)
    assert(cell_coords[1] < 4 && cell_coords[1] >= 0)
    using rl
    box_rect := get_cell_rect(cell_coords)
    return CheckCollisionPointRec(mouse_position,box_rect)
}
