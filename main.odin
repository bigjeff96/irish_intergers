package irish_integers

import "core:fmt"
import "core:c"
import "core:math/rand"
import "core:mem"
import mu "vendor:microui"
import mu_rl "micro_ui_raylib"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 1080
WINDOW_WIDTH :: 1920
FONT_SIZE :: 69
FONT_SPACING :: 5
BOARD_SIZE :: 500

main :: proc() {
    using rl, mu_rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Irish Integers")
    defer CloseWindow()

    // TODO: Make an init function fo microui ctx 
    // microui
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = {0xff, 0xff, 0xff, alpha}
    }
    defer delete(pixels)

    image := rl.Image {
        data    = raw_data(pixels),
        width   = mu.DEFAULT_ATLAS_WIDTH,
        height  = mu.DEFAULT_ATLAS_HEIGHT,
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8A8,
    }
    ui_state.atlas_texture = rl.LoadTextureFromImage(image)
    defer rl.UnloadTexture(ui_state.atlas_texture)

    ctx := &ui_state.mu_ctx
    mu.init(ctx)
    ctx.text_width = rl_text_width
    ctx.text_height = rl_text_height
    ctx.style.spacing += 3

    SetTargetFPS(60)
    game := init_game()
    for !WindowShouldClose() {
        using game
        mu_input(ctx)
        if IsKeyPressed(.Q) do break
        if IsKeyPressed(.R) {
            mem.set(&game.board, 0, size_of(Cell_state) * 16)
            for number_piece in &game.number_pieces do number_piece.piece_state = .HIDDEN
            state = .NEW_PIECE
        }
        game_logic(&game, ctx)
        render_game(&game, ctx)
        free_all(context.temp_allocator)
    }
}

game_logic :: proc(game: ^Game, ctx: ^mu.Context) {
    using rl, game
    mouse_position := GetMousePosition()

    mu.begin(ctx)
    defer mu.end(ctx)

    @(static)
    opts := mu.Options{.NO_FRAME, .NO_TITLE, .NO_INTERACT, .NO_RESIZE, .NO_SCROLL}

    if mu.window(
           ctx,
           "a series of buttons",
           mu.Rect{auto_cast board.rect.x + 550, auto_cast board.rect.y + 125, 320, 100},
           opts,
       ) {
        mu.layout_row(ctx, {-1}, 30) // 30 for good height of the buttons
        // hidden -> flipped <-> in_hand -> on_board      
        //              ^                         /       
        //              \ _______________________/ (swap) 
        switch state {
        case .NEW_PIECE:
            if .SUBMIT in mu.button(ctx, "Flip a piece", .NONE, {}) {
                piece_in_hand = take_random_piece_in_hand(game.number_pieces[:], .HIDDEN)
                state = .PIECE_IN_HAND
            }

            if .SUBMIT in mu.button(ctx, "Take a known piece RNG", .NONE, {}) {
                //Take a random known piece
                total_flipped := 0
                for number_piece in number_pieces {
                    if number_piece.piece_state == .FLIPPED do total_flipped += 1
                }
                if total_flipped != 0 {
                    piece_in_hand = take_random_piece_in_hand(number_pieces[:], .FLIPPED)
                    state = .PIECE_IN_HAND

                    for i in 0 ..< flipped_board.rows {
                        for j in 0 ..< flipped_board.columns {
                            cell := get_board_cell(flipped_board, {i, j})
                            number_on_cell, ok := cell.number.?
                            if ok {
                                if number_on_cell == piece_in_hand.?.number {
                                    cell.number = nil
                                }
                            }
                        }
                    }
                } else do fmt.println("No more flipped pieces")
            }

            // NOTE: not great, makes the game less interactive
            for i in 0 ..< board.rows {
                for j in 0 ..< board.columns {
                    get_board_cell(board, {i, j}).highlighted = false
                }
            }

        case .PIECE_IN_HAND:
            if .SUBMIT in mu.button(ctx, "Leave the piece", .NONE, {}) {
                piece_in_hand.?.piece_state = .FLIPPED
                number := piece_in_hand.?.number
                flipped_board.cells[number - 1].number = number
                state = .NEW_PIECE
                piece_in_hand = nil
                return
            }

            one_cell_selected := false // only 1 cell to interact at a time
            mouse_in_ui := mu_rl.mouse_in_ui(ctx)
            //check collision with each cell
            for i in 0 ..< board.rows {
                for j in 0 ..< board.columns {
                    if mouse_in_ui {
                        get_board_cell(board, {i, j}).highlighted = false
                        continue
                    }
                    cell_rect := get_cell_rect(board, {i, j})
                    collision := CheckCollisionPointRec(mouse_position, cell_rect)
                    if collision && IsMouseButtonUp(.LEFT) && !one_cell_selected {
                        get_board_cell(board, {i, j}).highlighted = true
                        one_cell_selected = true
                    } else if collision && !IsMouseButtonUp(.LEFT) && !one_cell_selected {
                        using a := get_board_cell(board, {i, j})
                        highlighted = true
                        one_cell_selected = true
                        _, ok := number.?
                        if !ok {
                            number = piece_in_hand.?.number
                            piece_in_hand = nil
                            state = .NUMBER_PLACED
                        } else {
                            // swapping pieces
                            number_pieces[number.? - 1].piece_state = .FLIPPED
                            flipped_board.cells[number.? - 1].number = number
                            number = piece_in_hand.?.number
                            piece_in_hand = nil
                            state = .NUMBER_PLACED
                        }
                    } else do get_board_cell(board, {i, j}).highlighted = false
                }
            }
        case .NUMBER_PLACED:
            if IsMouseButtonReleased(.LEFT) do state = .NEW_PIECE
        }
    }
}

render_game :: proc(game: ^Game, ctx: ^mu.Context) {
    using rl, game
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(BLACK)
    // draw board_rect and line separators
    defer {
        render_board(
            board = board,
            font_size = FONT_SIZE,
            font_spacing = FONT_SPACING,
            boarder_thickness = 6,
            grid_thickness = 3,
        )
        mu_rl.render(ctx)
    }


    // number to place, right of the board
    DrawText(
        fmt.ctprintf("Number in hand:"),
        auto_cast (board.rect.x + board.rect.width + 50),
        auto_cast board.rect.y + 20,
        25,
        RAYWHITE,
    )

    piece_in_hand_ok, ok := piece_in_hand.?
    if ok {
        DrawText(
            fmt.ctprintf("%d", piece_in_hand_ok.number),
            auto_cast (board.rect.x + board.rect.width + 120),
            auto_cast board.rect.y + 59,
            FONT_SIZE,
            RAYWHITE,
        )
    }

    DrawText(
        fmt.ctprintf("Flipped Pieces:"),
        auto_cast flipped_board.rect.x,
        auto_cast flipped_board.rect.y - 75,
        FONT_SIZE - 20,
        RAYWHITE,
    )
    // render the flipped numbers
    render_board(board = flipped_board, font_size = 30, font_spacing = 5, boarder_thickness = 2, grid_thickness = 1)
}

Game :: struct {
    state:             Game_state,
    piece_in_hand:     Maybe(^Number_piece),
    board:             Board_matrix,
    flipped_board:     Board_matrix,
    number_pieces:     [20]Number_piece,
    next_flipped_cell: int,
}

Game_state :: enum {
    NEW_PIECE,
    PIECE_IN_HAND,
    NUMBER_PLACED,
}

Rectangle_cint :: struct {
    x, y, width, height: c.int,
}

Cell_state :: struct {
    number:      Maybe(int),
    highlighted: bool,
}

// if number is zero -> no number in cell
Board_matrix :: struct {
    cells:         []Cell_state,
    rows:          int,
    columns:       int,
    rect:          rl.Rectangle,
    square_length: f32,
}

// hidden -> flipped <-> in_hand -> on_board      
//              ^                         /       
//              \ _______________________/ (swap) 
Number_piece :: struct {
    piece_state: Piece_state,
    number:      int,
}

Piece_state :: enum {
    HIDDEN,
    FLIPPED, // known but not in hand  
    IN_HAND,
    ON_BOARD,
}
init_game :: proc() -> Game {
    game: Game
    for i in 1 ..= 20 {
        game.number_pieces[i - 1].number = i
    }

    {
        using game.board
        rows = 4
        columns = 4
        cells = make([]Cell_state, rows * columns)
        rect = rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
        square_length = rect.width / auto_cast columns
    }

    {
        using game.flipped_board
        rows = 2
        columns = 10
        cells = make([]Cell_state, rows * columns)
        rect = game.board.rect
        rect.y -= 200
        rect.x -= 100
        square_length = rect.width / auto_cast columns
        rect.height = 2 * square_length
    }

    when ODIN_DEBUG {
        game.number_pieces[0].piece_state = .FLIPPED
        game.flipped_board.cells[0].number = game.number_pieces[0].number
        game.number_pieces[1].piece_state = .FLIPPED
        game.flipped_board.cells[1].number = game.number_pieces[1].number
        game.number_pieces[2].piece_state = .FLIPPED
        game.flipped_board.cells[2].number = game.number_pieces[2].number
    }
    return game
}

draw_number_in_cell :: proc(
    board: Board_matrix,
    cell_coords: [2]int,
    font_size := FONT_SIZE,
    font_spacing := FONT_SPACING,
) -> (
    drawn: bool,
) {
    number := get_board_cell(board, cell_coords).number.? or_return
    assert(cell_coords[0] < board.rows && cell_coords[0] >= 0)
    assert(cell_coords[1] < board.columns && cell_coords[1] >= 0)
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, auto_cast font_size, auto_cast font_spacing)
    box_rect := get_cell_rect(board, cell_coords)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(board.square_length - measure.x) / 2, (board.square_length - measure.y) / 2 + 5},
        auto_cast font_size,
        auto_cast font_spacing,
        RAYWHITE,
    )
    return
}

draw_number_in_square :: proc(board: Board_matrix, number: int, cell_coords: [2]int, font_size: f32) {
    if number == 0 do return
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, FONT_SIZE, FONT_SPACING)
    box_rect := get_cell_rect(board, cell_coords)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(board.square_length - measure.x) / 2, (board.square_length - measure.y) / 2 + 5},
        font_size,
        FONT_SPACING,
        RAYWHITE,
    )
}

take_random_piece_in_hand :: proc(
    number_pieces: []Number_piece,
    piece_type_to_take: Piece_state,
) -> Maybe(^Number_piece) {
    indices_of_pieces_of_interest := make([dynamic]int, context.temp_allocator)

    number_pieces := number_pieces
    for number_piece, i in number_pieces {
        using number_piece
        if piece_state == piece_type_to_take {
            append(&indices_of_pieces_of_interest, i)
        }
    }
    assert(len(indices_of_pieces_of_interest) > 0)
    index_of_piece_to_flip := rand.choice(indices_of_pieces_of_interest[:])
    number_pieces[index_of_piece_to_flip].piece_state = .IN_HAND
    return &number_pieces[index_of_piece_to_flip]
}

get_cell_rect :: #force_inline proc(board: Board_matrix, cell_coords: [2]int) -> rl.Rectangle {
    square_length := board.rect.width / auto_cast board.columns
    return(
        rl.Rectangle{
            x = board.rect.x + square_length * auto_cast cell_coords.y,
            y = board.rect.y + square_length * auto_cast cell_coords.x,
            width = square_length,
            height = square_length,
        } \
    )
}

render_board :: proc(board: Board_matrix, font_size, font_spacing, boarder_thickness, grid_thickness: int) {
    using rl, board
    origine := Vector2{rect.x, rect.y}
    for i in 0 ..< rows {
        for j in 0 ..< columns {
            using current_cell := get_board_cell(board, {i, j})
            if highlighted {
                cell_rect := get_cell_rect(board, {i, j})
                DrawRectangleRec(cell_rect, GRAY)
            }
        }
    }
    // board_rect
    DrawRectangleLinesEx(rect, auto_cast boarder_thickness, RAYWHITE)
    // vertical
    for i in 0 ..< columns - 1 {
        x: f32 = auto_cast square_length * (auto_cast i + 1)
        start := origine + {x, 0}
        end := origine + {x, rect.height}
        DrawLineEx(start, end, auto_cast grid_thickness, RAYWHITE)
    }
    // horizontal
    for i in 0 ..< rows - 1 {
        y: f32 = auto_cast square_length * (auto_cast i + 1)
        start := origine + {0, y}
        end := origine + {rect.width, y}
        DrawLineEx(start, end, auto_cast grid_thickness, RAYWHITE)
    }
    // numbers
    for i in 0 ..< rows {
        for j in 0 ..< columns {
            draw_number_in_cell(board, {i, j}, font_size, font_spacing)
        }
    }
}

get_board_cell :: #force_inline proc(board: Board_matrix, cell_coords: [2]int) -> ^Cell_state {
    using board
    assert(cell_coords[0] >= 0 && cell_coords[0] < rows)
    assert(cell_coords[1] >= 0 && cell_coords[1] < columns)
    return &cells[cell_coords[0] + cell_coords[1] * rows]
}
