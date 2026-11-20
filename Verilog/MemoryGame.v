// AI assistance: OpenAI Codex. Standalone memory puzzle, not the full game.
// SW[0..8] = squares 1..9, row-major. Return ALL switches OFF between entries.
// KEY0 = submit; SW9 ON = full reset (OFF = play). KEY1 is reserved for PIN scrolling.

// 1. BOARD CONNECTIONS: connect switches, buttons, game logic and displays.
module MemoryGame #(
    parameter integer FILTER_CYCLES = 1000000,
    parameter integer SHOW_CYCLES = 35000000,
    parameter integer GAP_CYCLES = 15000000,
    parameter integer RESULT_CYCLES = 75000000
) (
    MAX10_CLK1_50,
    KEY,
    SW,
    HEX0,
    HEX1,
    HEX2,
    HEX3,
    HEX4,
    HEX5,
    LEDR,
    VGA_R,
    VGA_G,
    VGA_B,
    VGA_HS,
    VGA_VS,
    stage_done,
    start
);

    // Inputs and outputs, written separately like the lab modules.
    input MAX10_CLK1_50;
    input [1:0] KEY;
    input [9:0] SW;
    output [7:0] HEX0;
    output [7:0] HEX1;
    output [7:0] HEX2;
    output [7:0] HEX3;
    output [7:0] HEX4;
    output [7:0] HEX5;
    output [9:0] LEDR;
    output [3:0] VGA_R;
    output [3:0] VGA_G;
    output [3:0] VGA_B;
    output VGA_HS;
    output VGA_VS;
    output stage_done;
    input start; // Allows VGA to run before memory sequence starts.

    wire reset_request = SW[9];
    reg [1:0] reset_sync;

    always @(posedge MAX10_CLK1_50 or posedge reset_request) begin
        if (reset_request) begin
            reset_sync <= 0;
        end
        else begin
            reset_sync <= {reset_sync[0], 1'b1};
        end
    end
    wire rst = !reset_sync[1];
    wire [9:0] switches;
    wire [0:0] submit_level;

    stable_input #(
        .WIDTH(10),
        .CYCLES(FILTER_CYCLES),
        .INITIAL(0)
    ) switch_filter (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .raw({1'b0, SW[8:0]}),
        .clean(switches)
    );

    stable_input #(
        .WIDTH(1),
        .CYCLES(FILTER_CYCLES),
        .INITIAL(1)
    ) button_filter (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .raw(KEY[0]),
        .clean(submit_level)
    );
    reg previous_button;
    wire submit = previous_button && !submit_level[0];

    // Detect one button press, rather than counting every clock it is held.
    always @(posedge MAX10_CLK1_50) begin
        if (rst) begin
            previous_button <= 1;
        end
        else begin
            previous_button <= submit_level[0];
        end
    end
    wire [3:0] shown, entered, round_length;
    wire [3:0] message;

    memory_core #(
        .SHOW_CYCLES(SHOW_CYCLES),
        .GAP_CYCLES(GAP_CYCLES),
        .RESULT_CYCLES(RESULT_CYCLES)
    ) core (
        .clk(MAX10_CLK1_50),
        .rst(rst || !start),
        .switches(switches),
        .submit(submit),
        .shown(shown),
        .entered(entered),
        .round_length(round_length),
        .message(message),
        .stage_done(stage_done)
    );
    wire [3:0] row = (shown - 1) / 3 + 1, col = (shown - 1) % 3 + 1;
    memory_hex h0 (shown == 0 ? 4'hf: col, HEX0);
    memory_hex h1 (shown == 0 ? 4'hf: row, HEX1);
    memory_hex h2 (4'hf, HEX2);
    memory_hex h3 (entered, HEX3);
    memory_hex h4 (4'hf, HEX4);
    memory_hex h5 (round_length, HEX5);
    assign LEDR = { stage_done, 9'b0 } | ((shown >= 1 && shown <= 9) ? (10'b1 << (shown - 1)): 10'b0);

    memory_vga video (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .message(message),
        .shown_square(shown),
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B),
        .hs(VGA_HS),
        .vs(VGA_VS)
    );

endmodule

// Accept an entire input vector only after it remains stable.

// 2. INPUT FILTER: wait for a stable input before accepting it.
module stable_input #(
    parameter WIDTH = 1,
    parameter integer CYCLES = 1000000,
    parameter [WIDTH - 1:0] INITIAL = 0
) (
    clk,
    rst,
    raw,
    clean
);

    // Inputs and outputs, written separately like the lab modules.
    input clk;
    input rst;
    input [WIDTH - 1:0] raw;
    output reg [WIDTH - 1:0] clean;

    reg [WIDTH - 1:0] meta, sync, candidate;
    reg [31:0] count;

    always @(posedge clk) begin
        if (rst) begin
            meta <= INITIAL;
            sync <= INITIAL;
            candidate <= INITIAL;
            clean <= INITIAL;
            count <= 0;
        end
        else begin
            meta <= raw;
            sync <= meta;
            if (sync != candidate) begin
                candidate <= sync;
                count <= 0;
            end
            else if (count == CYCLES - 1) begin
                clean <= candidate;
            end
            else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule

// 3. GAME LOGIC: generate, show, record and check each round.
module memory_core #(
    parameter integer SHOW_CYCLES = 35000000,
    GAP_CYCLES = 15000000,
    RESULT_CYCLES = 75000000
) (
    clk,
    rst,
    switches,
    submit,
    shown,
    entered,
    round_length,
    message,
    stage_done
);

    // Fixed-size loops describe repeated hardware, not timed software loops.
    integer j_loop1;
    integer k_loop2;

    // Inputs and outputs, written separately like the lab modules.
    input clk;
    input rst;
    input [9:0] switches;
    input submit;
    output reg [3:0] shown;
    output reg [3:0] entered;
    output reg [3:0] round_length;
    output reg [3:0] message;
    output stage_done;

    // Each state describes one step of the memory game.
    localparam [3:0] GENERATE_SEQUENCE       = 4'd0;
    localparam [3:0] SHOW_POSITION           = 4'd1;
    localparam [3:0] PAUSE_BETWEEN_POSITIONS  = 4'd2;
    localparam [3:0] READ_PLAYER_INPUT       = 4'd3;
    localparam [3:0] CHECK_ANSWER            = 4'd4;
    localparam [3:0] SHOW_CORRECT            = 4'd5;
    localparam [3:0] SHOW_TRY_AGAIN          = 4'd6;
    localparam [3:0] FINISHED                = 4'd7;
    reg [3:0] state;
    reg [3:0] seq_mem[0:3];     // The four correct square numbers.
    reg [3:0] answers[0:3];     // The player's recorded square numbers.
    reg [3:0] index;
    reg [31:0] delay_count;
    reg [15:0] lfsr;           // Pseudo-random sequence generator.
    reg ready_for_next_switch;
    reg [3:0] selected_square;
    reg all_answers_correct;
    integer i;
    integer switches_on;
    integer switch_number;

    // Count how many switches are ON. Only a count of one is accepted.
    always @(*) begin
        switches_on = 0;

        for (switch_number = 0; switch_number < 10; switch_number = switch_number + 1) begin
            if (switches[switch_number]) begin
                switches_on = switches_on + 1;
            end
        end
    end

    wire exactly_one_switch = (switches_on == 1);
    wire valid_selection = exactly_one_switch && !switches[9];
    wire multiple_switches = (switches != 0) && !exactly_one_switch;
    assign stage_done = (state == FINISHED);

    always @(*) begin
        selected_square = 0;
        // Convert the selected switch into a square number from 1 to 9.
        for (j_loop1 = 0; j_loop1 < 9; j_loop1 = j_loop1 + 1) begin
            if (switches[j_loop1]) begin
                selected_square = j_loop1 + 1;
            end
        end

        all_answers_correct = 1;
        // Compare only the entries required for the current round.
        for (k_loop2 = 0; k_loop2 < 4; k_loop2 = k_loop2 + 1) begin
            if (k_loop2 < round_length && answers[k_loop2] != seq_mem[k_loop2]) begin
                all_answers_correct = 0;
            end
        end

        shown = 0;
        if (state == SHOW_POSITION) begin
            shown = seq_mem[index];
        end
        else if (state == READ_PLAYER_INPUT && valid_selection) begin
            shown = selected_square;
        end
        case (state)
            GENERATE_SEQUENCE, SHOW_POSITION, PAUSE_BETWEEN_POSITIONS: message = 0;
            // WATCH

            READ_PLAYER_INPUT: begin
                if (multiple_switches) begin
                    message = 2;
                end
                // SLIDE ONE SWITCH ONLY
                else if (switches[9]) begin
                    message = 7;
                end
                // USE SWITCHES 0 TO 8
                else if (entered == round_length) begin
                    message = 3;
                end
                // PRESS KEY0 TO CHECK
                else begin
                    message = 1;
                end
                // ENTER SEQUENCE
            end

            CHECK_ANSWER: message = 3;

            SHOW_CORRECT: message = 4;

            SHOW_TRY_AGAIN: message = 5;

            FINISHED: message = 6;
            default: message = 0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= GENERATE_SEQUENCE;
            round_length <= 4;
            entered <= 0;
            index <= 0;
            delay_count <= 0;
            lfsr <= 16'hACE1;
            ready_for_next_switch <= 0;
            for (i = 0; i < 4; i = i + 1) begin
                seq_mem[i] <= 0;
                answers[i] <= 0;
            end
        end
        else begin
            lfsr <= { lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10] };
            case (state)

                GENERATE_SEQUENCE: begin
                    if (lfsr[3:0] < 9) begin
                        seq_mem[index] <= lfsr[3:0] + 1'b1;
                        if (index == 3) begin
                            index <= 0;
                            state <= SHOW_POSITION;
                            delay_count <= 0;
                        end
                        else begin
                            index <= index + 1'b1;
                        end
                    end
                end

                SHOW_POSITION: begin
                    if (delay_count == SHOW_CYCLES - 1) begin
                        delay_count <= 0;
                        state <= PAUSE_BETWEEN_POSITIONS;
                    end
                    else begin
                        delay_count <= delay_count + 1'b1;
                    end
                end

                PAUSE_BETWEEN_POSITIONS: begin
                    if (delay_count == GAP_CYCLES - 1) begin
                        delay_count <= 0;
                        if (index == round_length - 1) begin
                            state <= READ_PLAYER_INPUT;
                            entered <= 0;
                            ready_for_next_switch <= 0;
                        end
                        else begin
                            index <= index + 1'b1;
                            state <= SHOW_POSITION;
                        end
                    end
                    else begin
                        delay_count <= delay_count + 1'b1;
                    end
                end

                READ_PLAYER_INPUT: begin
                    // Wait for all switches to be OFF between entries.
                    if (switches == 0) begin
                        ready_for_next_switch <= 1;
                    end
                    else if (!valid_selection) begin
                        ready_for_next_switch <= 0;
                    end
                    // Error: preserve entries; require all OFF to re-arm.
                    else if (ready_for_next_switch) begin
                        ready_for_next_switch <= 0;
                        if (entered < round_length) begin
                            answers[entered] <= selected_square;
                            entered <= entered + 1'b1;
                        end
                    end
                    if (submit && entered == round_length && !multiple_switches && !switches[9]) begin
                        state <= CHECK_ANSWER;
                    end
                end

                CHECK_ANSWER: begin
                    delay_count <= 0;
                    if (all_answers_correct) begin
                        state <= SHOW_CORRECT;
                    end
                    else begin
                        state <= SHOW_TRY_AGAIN;
                    end
                end

                SHOW_CORRECT: begin
                    if (delay_count == RESULT_CYCLES - 1) begin
                        delay_count <= 0;
                        state <= FINISHED;
                    end
                    else begin
                        delay_count <= delay_count + 1'b1;
                    end
                end

                SHOW_TRY_AGAIN: begin
                    if (delay_count == RESULT_CYCLES - 1) begin
                        delay_count <= 0;
                        index <= 0;
                        entered <= 0;
                        ready_for_next_switch <= 0;
                        state <= SHOW_POSITION;
                    end
                    else begin
                        delay_count <= delay_count + 1'b1;
                    end
                end

                FINISHED: state <= FINISHED;
                default: state <= GENERATE_SEQUENCE;
            endcase
        end
    end

endmodule

// 4. SEVEN-SEGMENT DECODER: translate a digit into lit segments.
module memory_hex (
    n,
    seg
);

    // Inputs and outputs, written separately like the lab modules.
    input [3:0] n;
    output reg [7:0] seg;


    always @(*) case (n)
        0: seg = 8'hc0;
        1: seg = 8'hf9;
        2: seg = 8'ha4;
        3: seg = 8'hb0;
        4: seg = 8'h99;
        5: seg = 8'h92;
        6: seg = 8'h82;
        7: seg = 8'hf8;
        8: seg = 8'h80;
        9: seg = 8'h90;
        default: seg = 8'hff;
    endcase

endmodule

// 640x480 timing at a 25 MHz pixel enable (~59.5 Hz).
// Most VGA monitors accept this; a PLL at 25.175 MHz gives nominal timing.

// 5. VGA DISPLAY: flash the sequence on a 3x3 grid and show status above it.
module memory_vga (
    clk,
    rst,
    message,
    shown_square,
    red,
    green,
    blue,
    hs,
    vs
);

    // Inputs and outputs, written separately like the lab modules.
    input clk;
    input rst;
    input [3:0] message;
    input [3:0] shown_square;
    output reg [3:0] red;
    output reg [3:0] green;
    output reg [3:0] blue;
    output hs;
    output vs;

    reg pixel_enable;
    reg [9:0] x, y;
    reg [3:0] frame_message;
    reg [3:0] frame_square;

    always @(posedge clk) begin
        if (rst) begin
            pixel_enable <= 0;
            x <= 0;
            y <= 0;
            frame_message <= 0;
            frame_square <= 0;
        end
        else begin
            pixel_enable <= ~ pixel_enable;
            if (pixel_enable) begin
                if (x == 799) begin
                    x <= 0;
                    if (y == 524) begin
                        y <= 0;
                        frame_message <= message;
                        frame_square <= shown_square;
                    end
                    else begin
                        y <= y + 1'b1;
                    end
                end
                else begin
                    x <= x + 1'b1;
                end
            end
        end
    end
    assign hs = !(x >= 656 && x < 752);
    assign vs = !(y >= 490 && y < 492);
    // Choose the letter at a particular position in the message.

    function [7:0] character;
        input [3:0] msg;
        input integer pos;
        begin
            character = " ";
            case (msg)
                0: case (pos)
                    0: character = "W";
                    1: character = "A";
                    2: character = "T";
                    3: character = "C";
                    4: character = "H";
                    default: character = " ";
                endcase
                1: case (pos)
                    0: character = "E";
                    1: character = "N";
                    2: character = "T";
                    3: character = "E";
                    4: character = "R";
                    5: character = " ";
                    6: character = "S";
                    7: character = "E";
                    8: character = "Q";
                    9: character = "U";
                    10: character = "E";
                    11: character = "N";
                    12: character = "C";
                    13: character = "E";
                    default: character = " ";
                endcase
                2: case (pos)
                    0: character = "S";
                    1: character = "L";
                    2: character = "I";
                    3: character = "D";
                    4: character = "E";
                    5: character = " ";
                    6: character = "O";
                    7: character = "N";
                    8: character = "E";
                    9: character = " ";
                    10: character = "S";
                    11: character = "W";
                    12: character = "I";
                    13: character = "T";
                    14: character = "C";
                    15: character = "H";
                    16: character = " ";
                    17: character = "O";
                    18: character = "N";
                    19: character = "L";
                    20: character = "Y";
                    default: character = " ";
                endcase
                3: case (pos)
                    0: character = "P";
                    1: character = "R";
                    2: character = "E";
                    3: character = "S";
                    4: character = "S";
                    5: character = " ";
                    6: character = "K";
                    7: character = "E";
                    8: character = "Y";
                    9: character = "0";
                    10: character = " ";
                    11: character = "T";
                    12: character = "O";
                    13: character = " ";
                    14: character = "C";
                    15: character = "H";
                    16: character = "E";
                    17: character = "C";
                    18: character = "K";
                    default: character = " ";
                endcase
                4: case (pos)
                    0: character = "C";
                    1: character = "O";
                    2: character = "R";
                    3: character = "R";
                    4: character = "E";
                    5: character = "C";
                    6: character = "T";
                    default: character = " ";
                endcase
                5: case (pos)
                    0: character = "T";
                    1: character = "R";
                    2: character = "Y";
                    3: character = " ";
                    4: character = "A";
                    5: character = "G";
                    6: character = "A";
                    7: character = "I";
                    8: character = "N";
                    default: character = " ";
                endcase
                6: case (pos)
                    0: character = "M";
                    1: character = "E";
                    2: character = "M";
                    3: character = "O";
                    4: character = "R";
                    5: character = "Y";
                    6: character = " ";
                    7: character = "C";
                    8: character = "O";
                    9: character = "M";
                    10: character = "P";
                    11: character = "L";
                    12: character = "E";
                    13: character = "T";
                    14: character = "E";
                    default: character = " ";
                endcase
                7: case (pos)
                    0: character = "U";
                    1: character = "S";
                    2: character = "E";
                    3: character = " ";
                    4: character = "S";
                    5: character = "W";
                    6: character = "I";
                    7: character = "T";
                    8: character = "C";
                    9: character = "H";
                    10: character = "E";
                    11: character = "S";
                    12: character = " ";
                    13: character = "0";
                    14: character = " ";
                    15: character = "T";
                    16: character = "O";
                    17: character = " ";
                    18: character = "8";
                    default: character = " ";
                endcase
                default: character = " ";
            endcase
        end
    endfunction
    // Each letter is a 5-column by 7-row picture. A 1 lights a pixel.

    function [34:0] glyph;
        input [7:0] ch;
        begin
            case (ch)
                "A": glyph = 35'b01110_10001_10001_11111_10001_10001_10001;
                "C": glyph = 35'b01111_10000_10000_10000_10000_10000_01111;
                "D": glyph = 35'b11110_10001_10001_10001_10001_10001_11110;
                "E": glyph = 35'b11111_10000_10000_11110_10000_10000_11111;
                "G": glyph = 35'b01111_10000_10000_10111_10001_10001_01111;
                "H": glyph = 35'b10001_10001_10001_11111_10001_10001_10001;
                "I": glyph = 35'b11111_00100_00100_00100_00100_00100_11111;
                "K": glyph = 35'b10001_10010_10100_11000_10100_10010_10001;
                "L": glyph = 35'b10000_10000_10000_10000_10000_10000_11111;
                "M": glyph = 35'b10001_11011_10101_10101_10001_10001_10001;
                "N": glyph = 35'b10001_11001_10101_10011_10001_10001_10001;
                "O": glyph = 35'b01110_10001_10001_10001_10001_10001_01110;
                "P": glyph = 35'b11110_10001_10001_11110_10000_10000_10000;
                "Q": glyph = 35'b01110_10001_10001_10001_10101_10010_01101;
                "R": glyph = 35'b11110_10001_10001_11110_10100_10010_10001;
                "S": glyph = 35'b01111_10000_10000_01110_00001_00001_11110;
                "T": glyph = 35'b11111_00100_00100_00100_00100_00100_00100;
                "U": glyph = 35'b10001_10001_10001_10001_10001_10001_01110;
                "W": glyph = 35'b10001_10001_10001_10101_10101_10101_01010;
                "Y": glyph = 35'b10001_10001_01010_00100_00100_00100_00100;
                "0": glyph = 35'b01110_10001_10011_10101_11001_10001_01110;
                "8": glyph = 35'b01110_10001_10001_01110_10001_10001_01110;
                default: glyph = 0;
            endcase
        end
    endfunction
    integer letter_column, letter_row, pos;
    integer grid_column, grid_row, cell_number;
    integer cell_x, cell_y;
    reg [34:0] letter_pixels;
    reg text_pixel;

    always @(*) begin
        red = 0;
        green = 0;
        blue = 0;
        letter_column = 0;
        letter_row = 0;
        pos = 0;
        letter_pixels = 0;
        text_pixel = 0;
        grid_column = 0;
        grid_row = 0;
        cell_number = 0;
        cell_x = 0;
        cell_y = 0;

        if (x < 640 && y < 480) begin
            blue = 4'h2;

            // Row-major mapping matches SW0..SW8:
            //   1 2 3
            //   4 5 6
            //   7 8 9
            // A blank gap between flashes also distinguishes repeated cells.
            if (x >= 170 && x < 470 && y >= 110 && y < 410) begin
                grid_column = (x - 170) / 100;
                grid_row = (y - 110) / 100;
                cell_number = grid_row * 3 + grid_column + 1;
                cell_x = (x - 170) % 100;
                cell_y = (y - 110) % 100;

                // Leave a dark margin between cells.
                if (cell_x >= 4 && cell_x < 96 && cell_y >= 4 && cell_y < 96) begin
                    red = 2;
                    green = 3;
                    blue = 5;

                    if (frame_square == cell_number) begin
                        if (frame_message == 0) begin
                            // Cyan flash while the game is showing the sequence.
                            red = 0;
                            green = 15;
                            blue = 15;
                        end
                        else begin
                            // Green highlight for the player's current selection.
                            red = 0;
                            green = 15;
                            blue = 3;
                        end
                    end
                end
            end

            // Status text stays above the grid.
            if (x >= 68 && x < 572 && y >= 40 && y < 68) begin
                pos = (x - 68) / 24;
                letter_column = ((x - 68) % 24) / 4;
                letter_row = (y - 40) / 4;
                letter_pixels = glyph (character (frame_message, pos));
                if (letter_column < 5 && letter_row < 7) begin
                    text_pixel = letter_pixels[34 - (letter_row * 5 + letter_column)];
                end
                if (text_pixel) begin
                    if (frame_message == 4 || frame_message == 6) begin
                        red = 0;
                        green = 15;
                        blue = 0;
                    end
                    else if (frame_message == 2 || frame_message == 5 || frame_message == 7) begin
                        red = 15;
                        green = 4;
                        blue = 0;
                    end
                    else begin
                        red = 15;
                        green = 15;
                        blue = 15;
                    end
                end
            end
        end
    end

endmodule
