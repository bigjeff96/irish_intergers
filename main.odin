package irish_integers

WINDOW_HEIGHT :: 1080
WINDOW_WIDTH :: 1920
FONT_SIZE :: 69
FONT_SPACING :: 5
BOARD_SIZE :: 500

PROFILLING :: true
FPS :: false

Game :: struct {
    state:                  Game_state,
    player_turn:            int, // 0 not initialized, 1 player 1, 2 player 2
    piece_in_hand:          Maybe(^Number_piece),
    main_board:             Board_matrix,
    side_board:             Board_matrix,
    new_piece_on_board:     Maybe(^Number_piece),
    other_piece_if_swapped: Maybe(^Number_piece),
    swapping:               bool,
    flipped_board:          Board_matrix,
    number_pieces:          []Number_piece,
    next_flipped_cell:      int,
    highlight_logic:        struct {
        board_type: Board_type,
        cell_coord: [2]int,
    },
}

Game_state :: enum {
    NEW_PIECE,
    PIECE_IN_HAND,
    VALIDATE_PIECE_ON_BOARD,
    NUMBER_PLACED,
    WIN,
}

// if number is zero -> no number in cell
Board_matrix :: struct {
    rows:          int,
    columns:       int,
    rect:          rl.Rectangle,
    square_length: f32,
}

// hidden -> flipped <-> in_hand <-> validate_board -> on_board      
//              ^                                        /       
//              \ ______________________________________/ (swap) 
Number_piece :: struct {
    piece_state: Piece_state,
    index:       int,
    number:      int,
    cell_coords: [2]int,
    board_id:    int,
}

Piece_state :: enum {
    HIDDEN,
    FLIPPED, // known but not in hand  
    IN_HAND,
    ON_A_BOARD,
}

Board_type :: enum {
    NONE,
    BOARD,
    FLIPPED,
    SIDE,
}

game_logic :: proc(game: ^Game, ctx: ^mu.Context) {
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    using rl, game
    mouse_position := GetMousePosition()

    mu.begin(ctx)
    defer mu.end(ctx)

    @(static)
    opts := mu.Options{.NO_FRAME, .NO_TITLE, .NO_INTERACT, .NO_RESIZE, .NO_SCROLL}

    pieces_on_board := get_pieces_on_board(game.number_pieces, player_turn)

    if mu.window(
           ctx,
           "a series of buttons",
           mu.Rect{auto_cast main_board.rect.x + 550, auto_cast main_board.rect.y + 125, 213, 100},
           opts,
       ) {
        mu.layout_row(ctx, {-1}, 50) // 50 for good height of the buttons
        // hidden -> flipped <-> in_hand -> on_board      
        //              ^                         /       
        //              \ _______________________/ (swap) 
        switch state {
        case .NEW_PIECE:
            if .SUBMIT in mu.button(ctx, "Flip a piece", .NONE, {}) {
                piece_in_hand = take_random_piece_in_hand(game.number_pieces[:], .HIDDEN)
                _, ok := piece_in_hand.?
                if !ok do state = .NEW_PIECE
                else do state = .PIECE_IN_HAND
                highlight_logic.board_type = .NONE
                break
            }

            highlight_logic.board_type = .NONE
            mouse_position := GetMousePosition()
            mouse_in_ui := mu_rl.mouse_in_ui(ctx)
            mouse_on_flipped_board := CheckCollisionPointRec(mouse_position, flipped_board.rect)

            using flipped_board
            loop_flipped: for i in 0 ..< rows {
                for j in 0 ..< columns {
                    if mouse_in_ui || !mouse_on_flipped_board {
                        highlight_logic.board_type = .NONE
                        break loop_flipped
                    }
                    cell_rect := get_cell_rect(flipped_board, {i, j})
                    collision := CheckCollisionPointRec(mouse_position, cell_rect)

                    if collision && IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .FLIPPED
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                    } else if collision && !IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .FLIPPED
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                        index_piece_in_cell, ok := check_if_number_in_cell(number_pieces[:], {i, j})
                        if !ok {
                            state = .NEW_PIECE
                        } else {
                            // swapping pieces
                            piece_in_hand = &number_pieces[index_piece_in_cell]
                            piece_in_hand.?.piece_state = .IN_HAND
                            state = .PIECE_IN_HAND
                        }
                    }
                }
            }

        case .PIECE_IN_HAND:
            if .SUBMIT in mu.button(ctx, "Leave the piece", .NONE, {}) {
                piece_in_hand.?.piece_state = .FLIPPED
                number := piece_in_hand.?.number
                /* flipped_board.cells[number - 1].number = number */
                state = .NEW_PIECE
                piece_in_hand = nil
                player_turn = 2 if player_turn == 1 else 1
                return
            }

            highlight_logic.board_type = .NONE
            mouse_in_ui := mu_rl.mouse_in_ui(ctx)
            mouse_on_board := CheckCollisionPointRec(mouse_position, main_board.rect)
            //check collision with each cell
            loop_board: for i in 0 ..< main_board.rows {
                for j in 0 ..< main_board.columns {
                    if mouse_in_ui || !mouse_on_board {
                        highlight_logic.board_type = .NONE
                        break loop_board
                    }
                    cell_rect := get_cell_rect(main_board, {i, j})
                    collision := CheckCollisionPointRec(mouse_position, cell_rect)

                    if collision && IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .BOARD
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                    } else if collision && !IsMouseButtonUp(.LEFT) && highlight_logic.board_type == .NONE {
                        highlight_logic.board_type = .BOARD
                        highlight_logic.cell_coord = {i, j}
                        /* one_cell_selected = true */
                        piece := pieces_on_board[i + main_board.rows * j]
                        if piece == nil {
                            // placing piece on empty cell
                            piece_in_hand.?.piece_state = .ON_A_BOARD
                            piece_in_hand.?.cell_coords = {i, j}
                            piece_in_hand.?.board_id = player_turn
                            new_piece_on_board = piece_in_hand
                            piece_in_hand = nil
                            state = .VALIDATE_PIECE_ON_BOARD
                        } else {
                            // swapping pieces
                            swapping = true
                            other_piece_if_swapped = &number_pieces[piece.index]
                            other_piece_if_swapped.?.piece_state = .FLIPPED
                            piece_in_hand.?.piece_state = .ON_A_BOARD
                            piece_in_hand.?.cell_coords = {i, j}
                            piece_in_hand.?.board_id = player_turn
                            new_piece_on_board = piece_in_hand
                            piece_in_hand = nil
                            state = .VALIDATE_PIECE_ON_BOARD
                        }
                    }
                }
            }

        case .VALIDATE_PIECE_ON_BOARD:
            possible_piece := new_piece_on_board.?
            i, j := expand_values(possible_piece.cell_coords)
            pieces_on_board[i + main_board.rows * j] = possible_piece
            ok := check_board_is_valid(pieces_on_board)
            defer {swapping = false}
            if ok {
                state = .NUMBER_PLACED
                new_piece_on_board = nil
                if swapping do other_piece_if_swapped = nil
            } else {
                new_piece_on_board.?.piece_state = .IN_HAND
                piece_in_hand = new_piece_on_board
                state = .PIECE_IN_HAND
                if swapping {
                    other_piece_if_swapped.?.piece_state = .ON_A_BOARD
                    other_piece_if_swapped.?.cell_coords = new_piece_on_board.?.cell_coords
                }
                new_piece_on_board = nil
                other_piece_if_swapped = nil
            }

        case .NUMBER_PLACED:
            pieces_on_board = get_pieces_on_board(game.number_pieces, player_turn)
            total_empty_cells := 0
            for piece in pieces_on_board {
                if piece == nil do total_empty_cells += 1
            }
            if total_empty_cells == 0 {
                state = .WIN
                highlight_logic.board_type = .NONE
                break
            }
            if IsMouseButtonUp(.LEFT) {
                state = .NEW_PIECE
                player_turn = 2 if player_turn == 1 else 1
            }

        case .WIN:
        // do nothing
        }
    }

    check_if_number_in_cell :: proc(
        number_pieces: []Number_piece,
        cell_coords: [2]int,
    ) -> (
        piece_index: int,
        ok: bool,
    ) {
        i, j := expand_values(cell_coords)
        number := 10 * i + j + 1
        piece_one := number_pieces[number - 1]
        piece_two := number_pieces[number + 20 - 1]
        if number_pieces[number - 1].piece_state == .FLIPPED {
            piece_index = number - 1
            ok = true
            return
        } else if number_pieces[number - 1 + 20].piece_state == .FLIPPED {
            piece_index = number + 20 - 1
            ok = true
            return
        } else do return
    }

}

render_game :: proc(game: ^Game, ctx: ^mu.Context) {
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    using rl, game
    BeginDrawing()
    defer EndDrawing()

    ClearBackground(BLACK)
    // draw board_rect and line separators
    defer {
        render_board(game, .BOARD, FONT_SIZE, 6, 3)
        mu_rl.render(ctx)
    }
    // number to place, right of the board
    DrawText(
        fmt.ctprintf("Number in hand:"),
        auto_cast (main_board.rect.x + main_board.rect.width + 50),
        auto_cast main_board.rect.y + 20,
        25,
        RAYWHITE,
    )

    piece_in_hand_ok, ok := piece_in_hand.?
    if ok {
        DrawText(
            fmt.ctprintf("%d", piece_in_hand_ok.number),
            auto_cast (main_board.rect.x + main_board.rect.width + 120),
            auto_cast main_board.rect.y + 59,
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
    render_board(game, .FLIPPED, 30, 2, 1)
    render_board(game, .SIDE, 30, 2, 1)

    if state == .WIN {
        context.allocator = context.temp_allocator
        cstr := fmt.caprintf("Player %d Wins!!!", player_turn)
        text_length := MeasureText(cstr, FONT_SIZE)
        DrawText(
            cstr,
            auto_cast main_board.rect.x + auto_cast (main_board.rect.width - auto_cast text_length) / 2,
            auto_cast (main_board.rect.y + main_board.rect.height + 100),
            FONT_SIZE,
            RAYWHITE,
        )
    } else {
        // main board
        context.allocator = context.temp_allocator
        cstr := fmt.caprintf("Player %d", player_turn)
        text_length := MeasureText(cstr, FONT_SIZE)
        DrawText(
            cstr,
            auto_cast main_board.rect.x + auto_cast (main_board.rect.width - auto_cast text_length) / 2,
            auto_cast (main_board.rect.y + main_board.rect.height + 30),
            FONT_SIZE,
            RAYWHITE,
        )

        // side board
        cstr = fmt.caprintf("Player %d", 3 - player_turn)
        text_length = MeasureText(cstr, 30)
        DrawText(
            cstr,
            auto_cast side_board.rect.x + auto_cast (side_board.rect.width - auto_cast text_length) / 2,
            auto_cast (side_board.rect.y + side_board.rect.height + 20),
            30,
            RAYWHITE,
        )
    }

    // show time to render frame
    when FPS do DrawText(fmt.ctprintf("Frame Duration: %f ms", GetFrameTime() * 1000), 0, 0, 30, RAYWHITE)
}

init_game :: proc() -> Game {
    game: Game
    game.number_pieces = make([]Number_piece, 40)
    game.player_turn = 1
    for i in 1 ..= 20 {
        game.number_pieces[i - 1].number = i
        game.number_pieces[i - 1].index = i - 1
    }

    for i in 21 ..= 40 {
        game.number_pieces[i - 1].number = i - 20
        game.number_pieces[i - 1].index = i - 1
    }

    {
        using game.main_board
        rows = 4
        columns = 4
        rect = rl.Rectangle{(WINDOW_WIDTH - BOARD_SIZE) / 2, (WINDOW_HEIGHT - BOARD_SIZE) / 2, BOARD_SIZE, BOARD_SIZE}
        square_length = rect.width / auto_cast columns
    }

    {
        using game.flipped_board
        rows = 2
        columns = 10
        rect = game.main_board.rect
        rect.y -= 150
        rect.x -= 0
        square_length = rect.width / auto_cast columns
        rect.height = 2 * square_length
    }

    {
        using game.side_board
        rows = 4
        columns = 4
        square_length = game.flipped_board.square_length
        rect.width = square_length * 4
        rect.height = square_length * 4
        rect.x = 250
        rect.y = game.main_board.rect.y + (game.main_board.rect.height - rect.height) / 2
    }

    // choose 4 random pieces to put on the board
    for player in 1 ..= 2 {
        pieces_to_place: [4]^Number_piece

        for piece in &pieces_to_place {
            piece = take_random_piece_in_hand(game.number_pieces[:], .HIDDEN)
            piece.piece_state = .ON_A_BOARD
            piece.board_id = player
        }
        slice.sort_by_cmp(pieces_to_place[:], proc(a, b: ^Number_piece) -> slice.Ordering {
            number_a := a.number
            number_b := b.number
            diff := number_a - number_b
            return slice.Ordering(int(diff > 0) - int(diff < 0))
        })
        for piece, i in &pieces_to_place {
            piece.cell_coords = {i, i}
        }
    }
    return game
}

free_game :: proc(game: ^Game) {
    delete(game.number_pieces)
}

check_board_is_valid :: proc(pieces_on_board: []^Number_piece) -> bool {
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    rows := 4
    columns := 4

    // check if rows are valid
    for i in 0 ..< rows {
        piece_start := pieces_on_board[i]
        biggest_number_in_row := 0
        if piece_start != nil do biggest_number_in_row = piece_start.number
        for j in 1 ..< columns {
            possible_piece := pieces_on_board[i + j * rows]
            if possible_piece == nil do continue
            numb := possible_piece.number
            if numb > biggest_number_in_row {
                biggest_number_in_row = numb
                continue
            } else {
                return false
            }
        }
    }

    // check if columns are valid
    for j in 0 ..< columns {
        piece_start := pieces_on_board[j * rows]
        biggest_number_in_column := 0
        if piece_start != nil do biggest_number_in_column = piece_start.number
        for i in 1 ..< rows {
            possible_piece := pieces_on_board[i + j * rows]
            if possible_piece == nil do continue
            numb := possible_piece.number
            if numb > biggest_number_in_column {
                biggest_number_in_column = numb
                continue
            } else {
                return false
            }
        }
    }
    return true
}

get_pieces_on_board :: proc(
    number_pieces: []Number_piece,
    which_player: int,
    temp_allocator := context.temp_allocator,
) -> []^Number_piece {
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    rows := 4
    columns := 4
    number_pieces := number_pieces[:]
    board_numbers := make([]^Number_piece, rows * columns, temp_allocator)

    for piece in &number_pieces do if piece.piece_state == .ON_A_BOARD && piece.board_id == which_player {
            i, j := expand_values(piece.cell_coords)
            board_numbers[i + j * rows] = &piece
        }

    return board_numbers
}

draw_number_in_square :: #force_inline proc(board: Board_matrix, number: int, cell_coords: [2]int, font_size: f32) {
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    assert(number != 0)
    using rl
    font := GetFontDefault()
    text := fmt.ctprintf("%d", number)
    measure := MeasureTextEx(font, text, font_size, FONT_SPACING)
    box_rect := get_cell_rect(board, cell_coords)
    DrawTextEx(
        font,
        text,
        {box_rect.x, box_rect.y} + {(board.square_length - measure.x) / 2, (board.square_length - measure.y) / 2 + 2},
        font_size,
        FONT_SPACING,
        RAYWHITE,
    )
}

take_random_piece_in_hand :: proc(number_pieces: []Number_piece, piece_type_to_take: Piece_state) -> ^Number_piece {
    indices_of_pieces_of_interest := make([dynamic]int, context.temp_allocator)

    number_pieces := number_pieces
    for number_piece, i in number_pieces {
        using number_piece
        if piece_state == piece_type_to_take {
            append(&indices_of_pieces_of_interest, i)
        }
    }
    if len(indices_of_pieces_of_interest) == 0 do return nil
    /* assert(len(indices_of_pieces_of_interest) > 0) */
    index_of_piece_to_flip := rand.choice(indices_of_pieces_of_interest[:])
    number_pieces[index_of_piece_to_flip].piece_state = .IN_HAND
    return &number_pieces[index_of_piece_to_flip]
}

get_cell_rect :: #force_inline proc(using board: Board_matrix, cell_coords: [2]int) -> rl.Rectangle {
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    return(
        rl.Rectangle{
            x = rect.x + square_length * auto_cast cell_coords.y,
            y = rect.y + square_length * auto_cast cell_coords.x,
            width = square_length,
            height = square_length,
        } \
    )
}

render_board :: proc(game: ^Game, board_to_render: Board_type, font_size, boarder_thickness, grid_thickness: int) {
    when PROFILLING do spall.SCOPED_EVENT(
            &spall_ctx,
            &spall_buffer,
            #procedure,
            fmt.tprintf("rendering %v", board_to_render),
        )
    using rl
    board: Board_matrix

    switch board_to_render {
    case .BOARD:
        board = game.main_board
    case .FLIPPED:
        board = game.flipped_board
    case .SIDE:
        board = game.side_board
    case .NONE:
        panic("error in board rendering")
    }

    using board
    origine := Vector2{rect.x, rect.y}

    if game.highlight_logic.board_type == board_to_render {
        box_rect := get_cell_rect(board, game.highlight_logic.cell_coord)
        DrawRectangleRec(box_rect, GRAY)
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
    switch board_to_render {
    case .BOARD:
        board_numbers := get_pieces_on_board(game.number_pieces, game.player_turn)
        for i in 0 ..< rows {
            for j in 0 ..< columns {
                piece := board_numbers[i + j * rows]
                if piece != nil do draw_number_in_square(board, piece.number, {i, j}, auto_cast font_size)
            }
        }

    case .FLIPPED:
        for piece in game.number_pieces do if piece.piece_state == .FLIPPED {
                using piece
                i, j := (number - 1) / 10, (number - 1) % 10
                draw_number_in_square(board, number, {i, j}, auto_cast font_size)
            }

    case .SIDE:
        board_numbers := get_pieces_on_board(game.number_pieces, 3 - game.player_turn)
        for i in 0 ..< rows {
            for j in 0 ..< columns {
                piece := board_numbers[i + j * rows]
                if piece != nil do draw_number_in_square(board, piece.number, {i, j}, auto_cast font_size)
            }
        }

    case .NONE:
        panic("error in render_board")
    }
}

import "core:fmt"
import "core:math/rand"
import "core:slice"
import mu "vendor:microui"
import mu_rl "micro_ui_raylib"
import rl "vendor:raylib"
import "core:prof/spall"

spall_ctx: spall.Context
spall_buffer: spall.Buffer

main :: proc() {
    // spall
    spall_ctx = spall.context_create("trace_test.spall")
    defer spall.context_destroy(&spall_ctx)

    buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
    spall_buffer = spall.buffer_create(buffer_backing)
    defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

    using rl, mu_rl
    SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    SetTraceLogLevel(.WARNING)
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Irish Integers")
    defer CloseWindow()
    SetTargetFPS(60)
    ctx := raylib_cxt()
    game := init_game()
    defer free_game(&game)
    when PROFILLING do spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    for !WindowShouldClose() {
        mu_input(ctx)
        if IsKeyPressed(.Q) do break
        if IsKeyPressed(.R) {
            free_game(&game)
            game = init_game()
        }
        game_logic(&game, ctx)
        render_game(&game, ctx)
        free_all(context.temp_allocator)
    }
}
