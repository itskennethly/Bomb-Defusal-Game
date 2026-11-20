// AI assistance: OpenAI Codex. Four PIN boxes and per-position feedback.
// Screen: 0 = PIN, 1 = introduction, 2 = defused, 3 = failed.
module PinVga (
    clk,
    reset,
    screen,
    guess_digits,
    confirmed_boxes,
    current_box,
    feedback,
    reviewing,
    ready,
    red,
    green,
    blue,
    hs,
    vs
);

    // Fixed-size loops describe repeated hardware, not timed software loops.
    integer box_loop1;

    // Inputs and outputs, written separately like the lab modules.
    input clk;
    input reset;
    input [2:0] screen;
    input [15:0] guess_digits;
    input [3:0] confirmed_boxes;
    input [1:0] current_box;
    input [11:0] feedback;
    input reviewing;
    input ready;
    output reg [3:0] red;
    output reg [3:0] green;
    output reg [3:0] blue;
    output hs;
    output vs;

    reg pixel_enable;
    reg [9:0] x, y;
    reg [2:0] frame_screen;
    reg [1:0] frame_box;
    reg [15:0] frame_digits;
    reg [3:0] frame_confirmed;
    reg [11:0] frame_feedback;
    reg frame_reviewing, frame_ready;

    always @(posedge clk) begin
        if (reset) begin
            pixel_enable <= 0;
            x <= 0;
            y <= 0;
            frame_screen <= 1;
            frame_box <= 0;
            frame_digits <= 0;
            frame_confirmed <= 0;
            frame_feedback <= 0;
            frame_reviewing <= 0;
            frame_ready <= 0;
        end
        else begin
            pixel_enable <= ~pixel_enable;
            if (pixel_enable) begin
                if (x == 799) begin
                    x <= 0;
                    if (y == 524) begin
                        y <= 0;
                        frame_screen <= screen;
                        frame_box <= current_box;
                        frame_digits <= guess_digits;
                        frame_confirmed <= confirmed_boxes;
                        frame_feedback <= feedback;
                        frame_reviewing <= reviewing;
                        frame_ready <= ready;
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

    function [34:0] glyph;
        input [7:0] letter;
        begin
            case (letter)
                "0": glyph = 35'b01110_10001_10011_10101_11001_10001_01110;
                "1": glyph = 35'b00100_01100_00100_00100_00100_00100_01110;
                "2": glyph = 35'b01110_10001_00001_00010_00100_01000_11111;
                "3": glyph = 35'b11110_00001_00001_01110_00001_00001_11110;
                "4": glyph = 35'b00010_00110_01010_10010_11111_00010_00010;
                "5": glyph = 35'b11111_10000_10000_11110_00001_00001_11110;
                "6": glyph = 35'b01110_10000_10000_11110_10001_10001_01110;
                "7": glyph = 35'b11111_00001_00010_00100_01000_01000_01000;
                "8": glyph = 35'b01110_10001_10001_01110_10001_10001_01110;
                "9": glyph = 35'b01110_10001_10001_01111_00001_00001_01110;
                "?": glyph = 35'b01110_10001_00001_00010_00100_00000_00100;
                "A": glyph = 35'b01110_10001_10001_11111_10001_10001_10001;
                "B": glyph = 35'b11110_10001_10001_11110_10001_10001_11110;
                "C": glyph = 35'b01111_10000_10000_10000_10000_10000_01111;
                "D": glyph = 35'b11110_10001_10001_10001_10001_10001_11110;
                "E": glyph = 35'b11111_10000_10000_11110_10000_10000_11111;
                "F": glyph = 35'b11111_10000_10000_11110_10000_10000_10000;
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
                "X": glyph = 35'b10001_10001_01010_00100_01010_10001_10001;
                "Y": glyph = 35'b10001_10001_01010_00100_00100_00100_00100;
                default: glyph = 0;
            endcase
        end
    endfunction

    function letter_pixel;
        input [7:0] letter;
        input integer column;
        input integer row;
        reg [34:0] pixels;
        begin
            pixels = glyph(letter);
            letter_pixel = 0;
            if (column >= 0 && column < 5 && row >= 0 && row < 7) begin
                letter_pixel = pixels[34 - row * 5 - column];
            end
        end
    endfunction

    // Fixed-width strings keep the text logic straightforward.
    reg [255:0] title_text, help_text;
    reg [63:0] result_text;
    reg [7:0] character;
    reg text_on;
    integer box_left, box_status, box_digit;
    integer column, row, position;

    always @(*) begin
        title_text = "CRACK THE PIN                   ";
		  help_text  = "KEY1 SCROLL KEY0 CONFIRM        ";

        if (frame_reviewing) begin
            help_text = "KEY0 TO TRY AGAIN               ";
        end

        case (frame_screen)
            1: begin
                title_text = "PIN GAME COMPLETE               ";
                help_text = "MAKING MEMORY SEQUENCE          ";
            end
            4: begin
                title_text = "GET READY FOR PIN               ";
                help_text = "PIN STARTS IN 8 SECONDS         ";
            end
            2: begin
                title_text = "BOMB DEFUSED                    ";
                help_text = "TIMER STOPPED                   ";
            end
            3: begin
                title_text = "TIME UP                         ";
                help_text = "BOMB FAILED                     ";
            end
            default: begin end
        endcase

        red = 0;
        green = 0;
        blue = 0;
        result_text = "        ";
        character = " ";
        text_on = 0;
        box_left = 0;
        box_status = 0;
        box_digit = 0;
        column = 0;
        row = 0;
        position = 0;

        if (x < 640 && y < 480) begin
            blue = 2;

            // Header and controls above the boxes.
            if (x >= 32 && x < 608 && ((y >= 26 && y < 54) || (y >= 65 && y < 93))) begin
                // Larger 4x pixel font, with one full character pixel of spacing.
                position = (x - 32) / 24;
                column = ((x - 32) % 24) / 4;

                if (y < 54) begin
                    row = (y - 26) / 4;
                    character = title_text[255 - position * 8 -: 8];
                end
                else begin
                    row = (y - 65) / 4;
                    character = help_text[255 - position * 8 -: 8];
                end

                text_on = letter_pixel(character, column, row);
                if (text_on) begin
                    red = (frame_screen == 2) ? 0 : 15;
                    green = (frame_screen == 3) ? 0 : 15;
                    blue = (frame_screen == 2 || frame_screen == 3) ? 0 : 15;
                end
            end

            if (frame_screen == 0) begin
                for (box_loop1 = 0; box_loop1 < 4; box_loop1 = box_loop1 + 1) begin
                    box_left = 50 + box_loop1 * 135;
                    box_digit = frame_digits[box_loop1 * 4 +: 4];
                    box_status = frame_feedback[box_loop1 * 3 +: 3];

                    // Highlight the currently editable box_loop1.
                    if (x >= box_left && x < box_left + 120 && y >= 160 && y < 260) begin
                        if (box_loop1 == frame_box && frame_ready) begin
                            blue = 6;
                        end

                        if (x < box_left + 3 || x >= box_left + 117 || y < 163 || y >= 257) begin
                            red = 12;
                            green = 12;
                            blue = 12;
                        end
                    end

                    // Secret digits are never drawn. Show ? until a box_loop1 is edited.
                    if (x >= box_left + 40 && x < box_left + 80 && y >= 182 && y < 238) begin
                        character = "?";
                        if (frame_confirmed[box_loop1] || (box_loop1 == frame_box && frame_ready)) begin
                            character = 8'd48 + box_digit;
                        end

                        if (letter_pixel(character, (x - box_left - 40) / 8, (y - 182) / 8)) begin
                            red = 15;
                            green = 15;
                            blue = 15;
                        end
                    end

                    // Feedback is aligned beneath the digit it describes.
                    if (frame_reviewing && x >= box_left + 12 && x < box_left + 108 && y >= 280 && y < 294) begin
                        case (box_status)
                            1: result_text = "CORRECT ";
                            2: result_text = "CLOSE   ";
                            3: result_text = "NOT HERE";
                            4: result_text = "NO MORE ";
                            default: result_text = "        ";
                        endcase

                        position = (x - box_left - 12) / 12;
                        character = result_text[63 - position * 8 -: 8];
                        if (letter_pixel(character, ((x - box_left - 12) % 12) / 2, (y - 280) / 2)) begin
                            red = (box_status == 1) ? 0 : 15;
                            green = (box_status == 1 || box_status == 2) ? 15 : 2;
                            blue = 0;
                        end
                    end
                end
            end
        end
    end
endmodule
