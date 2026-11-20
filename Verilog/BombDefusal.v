// AI assistance: OpenAI Codex.
// Full progression: four-digit PIN -> memory -> defused.
// SW9 is the ONLY full reset. KEY0 confirms; KEY1 scrolls during PIN entry.
module BombDefusal #(
    parameter integer CLOCK_HZ = 50000000,
    parameter [12:0] START_SECONDS = 90,
    parameter integer FILTER_CYCLES = 1000000,
    parameter integer SHOW_CYCLES = 35000000,
    parameter integer GAP_CYCLES = 15000000,
    parameter integer RESULT_CYCLES = 75000000,
    parameter integer TRANSITION_CYCLES = 250000000, // 5 seconds at 50 MHz
    parameter integer STARTUP_CYCLES = 400000000 // 8 seconds at 50 MHz
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
    VGA_VS
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

    localparam [2:0] WAIT_PIN = 3'd5;
    localparam [2:0] PIN = 3'd0;
    localparam [2:0] NEXT_MEMORY = 3'd1;
    localparam [2:0] MEMORY = 3'd2;
    localparam [2:0] DEFUSED = 3'd3;
    localparam [2:0] FAILED = 3'd4;

    reg [1:0] reset_sync;

    always @(posedge MAX10_CLK1_50 or posedge SW[9]) begin
        if (SW[9]) begin
            reset_sync <= 0;
        end
        else begin
            reset_sync <= {reset_sync[0], 1'b1};
        end
    end

    wire reset = !reset_sync[1];
    reg [2:0] stage;
    reg [31:0] transition_count;
    wire memory_done, pin_solved;
    wire [12:0] seconds_left;
    wire time_up, expires_now;
    wire running = (stage == PIN || stage == NEXT_MEMORY || stage == MEMORY);

    // Timer never reloads between stages. It stops on success or timeout.
    CountdownTimer #(
        .CLOCK_HZ(CLOCK_HZ),
        .START_SECONDS(START_SECONDS)
    ) countdown (
        .clk(MAX10_CLK1_50), .reset(reset), .run(running),
        .seconds_left(seconds_left), .time_up(time_up), .expires_now(expires_now)
    );

    // All buttons are filtered independently. A held button creates one pulse.
    wire [8:0] selection;
    wire confirm_level, scroll_level;
    reg previous_confirm, previous_scroll;
    wire confirm = previous_confirm && !confirm_level;
    wire scroll = previous_scroll && !scroll_level;

    stable_input #(.WIDTH(9), .CYCLES(FILTER_CYCLES), .INITIAL(0)) switches_filter (
        .clk(MAX10_CLK1_50), .rst(reset), .raw(SW[8:0]), .clean(selection)
    );

    stable_input #(.WIDTH(1), .CYCLES(FILTER_CYCLES), .INITIAL(1)) confirm_filter (
        .clk(MAX10_CLK1_50), .rst(reset), .raw(KEY[0]), .clean(confirm_level)
    );

    stable_input #(.WIDTH(1), .CYCLES(FILTER_CYCLES), .INITIAL(1)) scroll_filter (
        .clk(MAX10_CLK1_50), .rst(reset), .raw(KEY[1]), .clean(scroll_level)
    );

    always @(posedge MAX10_CLK1_50) begin
        if (reset) begin
            previous_confirm <= 1;
            previous_scroll <= 1;
        end
        else begin
            previous_confirm <= confirm_level;
            previous_scroll <= scroll_level;
        end
    end

    always @(posedge MAX10_CLK1_50) begin
        if (reset) begin
            stage <= WAIT_PIN;
            transition_count <= 0;
        end
        else if (running && (time_up || expires_now)) begin
            // The deadline wins if success is being accepted on this same clock.
            stage <= FAILED;
        end
        else begin
            case (stage)
                WAIT_PIN: begin
                    // Eight-second startup pause; countdown stays at 02:00.
                    if (transition_count == STARTUP_CYCLES - 1) begin
                        stage <= PIN;
                        transition_count <= 0;
                    end
                    else begin
                        transition_count <= transition_count + 1'b1;
                    end
                end

                PIN: begin
                    if (pin_solved) begin
                        stage <= NEXT_MEMORY;
                        transition_count <= 0;
                    end
                end

                NEXT_MEMORY: begin
                    // Give VGA 5 seconds before starting the memory sequence.
                    // The memory VGA is already running; display it during
                    // the last second to ensure it is visible before any flash.
                    if (transition_count == TRANSITION_CYCLES - 1) begin
                        stage <= MEMORY;
                        transition_count <= 0;
                    end
                    else begin
                        transition_count <= transition_count + 1'b1;
                    end
                end

                MEMORY: begin
                    if (memory_done) begin
                        stage <= DEFUSED;
                    end
                end

                DEFUSED, FAILED: stage <= stage;
                default: stage <= WAIT_PIN;
            endcase
        end
    end

    wire [7:0] memory_hex0, memory_hex1;
    wire [9:0] memory_leds;
    wire [3:0] memory_red, memory_green, memory_blue;
    wire memory_hs, memory_vs;
    wire [1:0] memory_keys = {1'b1, (stage == MEMORY ? KEY[0] : 1'b1)};
    // Keep memory logic idle until the 5-second wait finishes.
    // Do NOT reset its VGA renderer between games.
    wire [9:0] memory_switches = SW;

    MemoryGame #(
        .FILTER_CYCLES(FILTER_CYCLES), .SHOW_CYCLES(SHOW_CYCLES),
        .GAP_CYCLES(GAP_CYCLES), .RESULT_CYCLES(RESULT_CYCLES)
    ) memory_stage (
        .MAX10_CLK1_50(MAX10_CLK1_50), .KEY(memory_keys), .SW(memory_switches),
        .start(stage == MEMORY),
        .HEX0(memory_hex0), .HEX1(memory_hex1),
        .HEX2(), .HEX3(), .HEX4(), .HEX5(),
        .LEDR(memory_leds),
        .VGA_R(memory_red), .VGA_G(memory_green), .VGA_B(memory_blue),
        .VGA_HS(memory_hs), .VGA_VS(memory_vs), .stage_done(memory_done)
    );

    wire [15:0] guess_digits;
    wire [3:0] confirmed_boxes;
    wire [1:0] current_box;
    wire [11:0] feedback;
    wire reviewing, pin_ready;

    pin_game pin_stage (
        .clk(MAX10_CLK1_50), .reset(reset),
        .active(stage == PIN || stage == NEXT_MEMORY || stage == MEMORY || stage == DEFUSED),
        .scroll(scroll), .confirm(confirm),
        .guess_digits(guess_digits), .confirmed_boxes(confirmed_boxes),
        .current_box(current_box), .feedback(feedback),
        .reviewing(reviewing), .solved(pin_solved), .ready(pin_ready)
    );

    reg [2:0] pin_screen;

    // Select which PIN/end-of-game screen to draw.
    always @(*) begin
        case (stage)
            WAIT_PIN:    pin_screen = 4; // PIN starts in 8 seconds
            NEXT_MEMORY: pin_screen = 1; // Making memory sequence
            DEFUSED:  pin_screen = 2;
            FAILED:   pin_screen = 3;
            default:  pin_screen = 0;
        endcase
    end

    wire [3:0] pin_red, pin_green, pin_blue;
    wire pin_hs, pin_vs;

    PinVga pin_video (
        .clk(MAX10_CLK1_50), .reset(reset), .screen(pin_screen),
        .guess_digits(guess_digits), .confirmed_boxes(confirmed_boxes),
        .current_box(current_box), .feedback(feedback),
        .reviewing(reviewing), .ready(pin_ready),
        .red(pin_red), .green(pin_green), .blue(pin_blue),
        .hs(pin_hs), .vs(pin_vs)
    );

    // Both VGA renderers run continuously from the same reset, so their
    // pixel counters remain aligned. Switch RGB only at a frame boundary.
    reg [1:0] video_source;
    reg previous_vs;

    always @(posedge MAX10_CLK1_50) begin
        if (reset) begin
            video_source <= 1;
            previous_vs <= 1;
        end
        else begin
            previous_vs <= pin_vs;
            if (!previous_vs && pin_vs) begin
                if (stage == MEMORY ||
                    (stage == NEXT_MEMORY && transition_count >= (TRANSITION_CYCLES - CLOCK_HZ))) begin
                    video_source <= 0;
                end
                else begin
                    video_source <= 1;
                end
            end
        end
    end

    reg [3:0] selected_red;
    reg [3:0] selected_green;
    reg [3:0] selected_blue;

    // This is a multiplexer: choose the outputs of one display module.
    always @(*) begin
        case (video_source)
            0: begin
                selected_red = memory_red;
                selected_green = memory_green;
                selected_blue = memory_blue;
            end

            default: begin
                selected_red = pin_red;
                selected_green = pin_green;
                selected_blue = pin_blue;
            end
        endcase
    end

    // Keep VGA sync alive and show the PIN / memory loading instructions.
    // The memory renderer is already running and stays synchronized.
    wire blank_wait = 1'b0; // Show instructions while both VGA renderers stay synchronized
    assign VGA_R = blank_wait ? 4'b0 : selected_red;
    assign VGA_G = blank_wait ? 4'b0 : selected_green;
    assign VGA_B = blank_wait ? 4'b0 : selected_blue;
    assign VGA_HS = (video_source == 0) ? memory_hs : pin_hs;
    assign VGA_VS = (video_source == 0) ? memory_vs : pin_vs;

    // Left four displays ALWAYS show MMSS. Right two show memory coordinates.
    wire [6:0] minutes = seconds_left / 60;
    wire [5:0] seconds = seconds_left % 60;
    wire [3:0] minute_tens = minutes / 10;
    wire [3:0] minute_ones = minutes % 10;
    wire [3:0] second_tens = seconds / 10;
    wire [3:0] second_ones = seconds % 10;

    memory_hex timer_digit3 (.n(minute_tens), .seg(HEX5));
    memory_hex timer_digit2 (.n(minute_ones), .seg(HEX4));
    memory_hex timer_digit1 (.n(second_tens), .seg(HEX3));
    memory_hex timer_digit0 (.n(second_ones), .seg(HEX2));

    assign HEX0 = (stage == MEMORY) ? memory_hex0 : 8'hFF;
    assign HEX1 = (stage == MEMORY) ? memory_hex1 : 8'hFF;
    reg [9:0] selected_leds;

    always @(*) begin
        case (stage)
            DEFUSED: selected_leds = 10'b1111111111;
            FAILED:  selected_leds = 10'b0000000000;
            MEMORY:  selected_leds = memory_leds;
            PIN:     selected_leds = {6'b0, confirmed_boxes};
            WAIT_PIN: selected_leds = 10'b0;
            default: selected_leds = 10'b0;
        endcase
    end

    assign LEDR = selected_leds;
endmodule
