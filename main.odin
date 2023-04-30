package irish_integers

import "core:fmt"
import "core:c"
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
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Irish Integers")
    defer CloseWindow()

    SetTargetFPS(60)
    game := init_game()
    for !WindowShouldClose() {
        using game
        if IsKeyPressed(.Q) do break
        if IsKeyPressed(.R) {
            mem.set(&game.board, 0, size_of(Cell_state) * 16)
            for number_piece in &game.number_pieces do number_piece.piece_state = .HIDDEN
            state = .NEW_NUMBER
        }
        update_game_state(&game)
        render_game(&game)
        free_all(context.temp_allocator)
    }
}

update_game_state :: proc(game: ^Game) {
    using rl, game
    mouse_position := GetMousePosition()
    switch state {
    case .NEW_NUMBER:
        number_to_place = flip_number_piece_and_put_in_hand(game.number_pieces[:]).number
        state = .NUMBER_TO_PLACE
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
                        number = number_to_place
                        state = .NUMBER_PLACED
                        number_pieces[number_to_place - 1].piece_state = .ON_BOARD
                    } else do fmt.println("cell already filled")
                } else do board[i][j].highlighted = false
            }
        }
    case .NUMBER_PLACED:
        if IsMouseButtonReleased(.LEFT) do state = .NEW_NUMBER
    }
}

render_game :: proc(game: ^Game) {
    using rl, game
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(BLACK)
    origine := Vector2{board_rect.x, board_rect.y}
    // draw board_rect and line separators
    defer {
        // board_rect
        DrawRectangleLinesEx(board_rect, 6, RAYWHITE)
        // vertical
        for i in 0 ..< 3 {
            x: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {x, 0}
            end := origine + {x, board_rect.height}
            DrawLineEx(start, end, 3, RAYWHITE)
        }
        // horizontal
        for i in 0 ..< 3 {
            y: f32 = auto_cast square_length * (auto_cast i + 1)
            start := origine + {0, y}
            end := origine + {board_rect.width, y}
            DrawLineEx(start, end, 3, RAYWHITE)
        }
        // numbers
        for i in 0 ..< 4 {
            for j in 0 ..< 4 {
                draw_number_in_cell(&board, {i, j})
            }
        }
    }

    for i in 0 ..< 4 {
        for j in 0 ..< 4 {
            using current_cell := board[i][j]
            if highlighted {
                cell_rect := get_cell_rect({i, j})
                DrawRectangleRec(cell_rect, GRAY)
            }
        }
    }

    // number to place, right of the board
    DrawText(
        fmt.ctprintf("Next number to place:"),
        auto_cast (board_rect.x + board_rect.width + 50),
        auto_cast board_rect.y + 20,
        25,
        RAYWHITE,
    )
    DrawText(
        fmt.ctprintf("%d", number_to_place),
        auto_cast (board_rect.x + board_rect.width + 150),
        auto_cast board_rect.y + 59,
        FONT_SIZE,
        RAYWHITE,
    )
}

Game :: struct {
    state:           Game_state,
    number_to_place: int,
    board:           Board_matrix,
    number_pieces:   [20]Number_piece,
}

Game_state :: enum {
    NEW_NUMBER,
    NUMBER_TO_PLACE,
    NUMBER_PLACED,
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

// hidden -> flipped <-> in_hand -> on_board      
//              ^                         /       
//              \ _______________________/ (swap) 
Number_piece :: struct {
    piece_state: enum {
        HIDDEN,
        FLIPPED, // known but not in hand  
        IN_HAND,
        ON_BOARD,
    },
    number:      int,
}

init_game :: proc() -> Game {
    game: Game
    for i in 1 ..= 20 {
        game.number_pieces[i - 1].number = i
    }
    return game
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
        RAYWHITE,
    )
}

flip_number_piece_and_put_in_hand :: proc(number_pieces: []Number_piece) -> ^Number_piece {
    indices_of_hidden_pieces := make([dynamic]int, context.temp_allocator)

    number_pieces := number_pieces
    for number_piece, i in number_pieces {
        using number_piece
        if piece_state == .HIDDEN {
            append(&indices_of_hidden_pieces, i)
        }
    }
    assert(len(indices_of_hidden_pieces) > 0)

    index_of_piece_to_flip := rand.choice(indices_of_hidden_pieces[:])
    number_pieces[index_of_piece_to_flip].piece_state = .IN_HAND
    return &number_pieces[index_of_piece_to_flip]
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
