package irish_integers

import "core:fmt"
import "core:c"
import "core:math"
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 1080
WINDOW_WIDTH :: 1920
FONT_SIZE :: 69
FONT_SPACING :: 5
BOARD_SIZE :: 500

board_rect := rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
square_length: f32 = BOARD_SIZE / 4

main :: proc() {
    using rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    /* SetTraceLogLevel(.WARNING) */
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "lul")
    defer CloseWindow()

    SetTargetFPS(60)

    board: Board_matrix
    state: Game_state = .NEW_NUMBER
    number_to_place: int
    for !WindowShouldClose() {
        if IsKeyPressed(.Q) do break
        if IsKeyPressed(.R) {
            mem.set(&board, 0, size_of(Cell_state) * 16)
            state = .NEW_NUMBER
        }
        update_game_state(&state, &number_to_place, &board)
        render_game(&board, &number_to_place)
        free_all(context.temp_allocator)
    }
}

update_game_state :: proc(state: ^Game_state, number_to_place: ^int, board: ^Board_matrix) {
    using rl
    mouse_position := GetMousePosition()
    switch state^ {
    case .NEW_NUMBER:
        number_to_place^ = random_number()
        state^ = .NUMBER_TO_PLACE
    case .NUMBER_TO_PLACE:
        //check collison with each cell
        for i in 0 ..< 4 {
            for j in 0 ..< 4 {
                cell_rect := get_cell_rect({i, j})
                collision := CheckCollisionPointRec(mouse_position, cell_rect)
                if collision && IsMouseButtonUp(.LEFT) {
                    board[i][j].highlighted = true
                } else if collision && !IsMouseButtonUp(.LEFT) {
                    using current_cell := &board[i][j]
                    highlighted = true
                    if number == 0 {
                        number = number_to_place^
                        state^ = .NEW_NUMBER
                    } else do fmt.println("cell already filled")
                } else do board[i][j].highlighted = false
            }
        }
    }
}

render_game :: proc(board: ^Board_matrix, number_to_place: ^int) {
    using rl
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(RAYWHITE)
    origine := Vector2{board_rect.x, board_rect.y}
    // draw board_rect and line separators
    defer {
        // board_rect
        DrawRectangleLinesEx(board_rect, 6, BLACK)
        // vertical
        for i in 0 ..< 3 {
            x: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {x, 0}
            end := origine + {x, board_rect.height}
            DrawLineEx(start, end, 3, BLACK)
        }
        // horizontal
        for i in 0 ..< 3 {
            y: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {0, y}
            end := origine + {board_rect.width, y}
            DrawLineEx(start, end, 3, BLACK)
        }
        // numbers
        for i in 0 ..< 4 {
            for j in 0 ..< 4 {
                draw_number_in_cell(board, {i, j})
            }
        }
    }

    for i in 0 ..< 4 {
        for j in 0 ..< 4 {
            using current_cell := board[i][j]
            if highlighted {
                cell_rect := get_cell_rect({i, j})
                DrawRectangleRec(cell_rect, YELLOW)
            }
        }
    }

    // number to place, right of the board
    DrawText(
        fmt.ctprintf("Next number to place:"),
        auto_cast (board_rect.x + board_rect.width + 50),
        auto_cast board_rect.y + 20,
        25,
        BLACK,
    )
    DrawText(
        fmt.ctprintf("%d", number_to_place^),
        auto_cast (board_rect.x + board_rect.width + 150),
        auto_cast board_rect.y + 59,
        FONT_SIZE,
        BLACK,
    )
}

Game_state :: enum {
    NUMBER_TO_PLACE,
    NEW_NUMBER,
}

Rectangle_cint :: struct {
    x, y, width, height: c.int,
}

Cell_state :: struct {
    number:      int,
    highlighted: bool,
}

// if number is zero -> no number in cell
Board_matrix :: distinct [4][4]Cell_state


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
    board: ^Board_matrix,
    cell_coords: [2]int,
    board_rect: rl.Rectangle = board_rect,
    square_length: f32 = square_length,
) {
    assert(cell_coords[0] < 4 && cell_coords[0] >= 0)
    assert(cell_coords[1] < 4 && cell_coords[1] >= 0)
    number := board[cell_coords.x][cell_coords.y].number
    assert(number <= 20 && number >= 0)
    // don't draw if cell is empty
    if number == 0 do return
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, FONT_SIZE, FONT_SPACING)
    box_rect := get_cell_rect(cell_coords)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(square_length - measure.x) / 2, (square_length - measure.y) / 2 + 5},
        FONT_SIZE,
        FONT_SPACING,
        BLACK,
    )
}

random_number :: #force_inline proc(lo := 1, hi := 20, r: ^rand.Rand = nil) -> int {
    number_float := rand.float64_range(1, 20)
    return int(number_float + 0.5)
}

get_cell_rect :: proc(cell_coords: [2]int, board_rect := board_rect, square_length := square_length) -> rl.Rectangle {
    assert(cell_coords[0] < 4 && cell_coords[0] >= 0)
    assert(cell_coords[1] < 4 && cell_coords[1] >= 0)
    return(
        rl.Rectangle{
            x = board_rect.x + square_length * auto_cast cell_coords.y,
            y = board_rect.y + square_length * auto_cast cell_coords.x,
            width = square_length,
            height = square_length,
        } \
    )
}
