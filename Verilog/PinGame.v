// Four unique secret digits 0..5. Guesses may repeat digits.
// KEY1 scrolls 0..5; KEY0 confirms, advances, or retries.
module PinGame (
    input clk, reset, active, scroll, confirm,
    output [15:0] guess_digits,
    output reg [3:0] confirmed_boxes,
    output reg [1:0] current_box,
    output [11:0] feedback,
    output reviewing, solved, ready
);
    localparam [2:0] GENERATE=0, ENTER_DIGITS=1, CHECK_GUESS=2,
                     SHOW_FEEDBACK=3, SOLVED=4;
    localparam [2:0] CORRECT=1, CLOSE=2, NOT_HERE=3, NO_MORE=4;
    reg [2:0] state;
    reg [3:0] secret [0:3];
    reg [2:0] generated_count;
    reg [5:0] generated_digits;
    reg [15:0] random_bits;
    reg [3:0] used_secret_positions;
    reg [3:0] guess [0:3];
    reg [2:0] result [0:3];
    reg [2:0] checked_result [0:3];
    reg found_available, digit_exists, all_correct;
    integer i, j, k, n;

    assign guess_digits = {guess[3],guess[2],guess[1],guess[0]};
    assign feedback = {result[3],result[2],result[1],result[0]};
    assign reviewing = (state == SHOW_FEEDBACK);
    assign solved = (state == SOLVED);
    assign ready = (state == ENTER_DIGITS);

    always @(posedge clk) begin
        if (reset)
            random_bits <= 16'hBEEF;
        else
            random_bits <= {random_bits[14:0],
                random_bits[15]^random_bits[13]^random_bits[12]^random_bits[10]};
    end

    always @(*) begin
        used_secret_positions = 0;
        found_available = 0;
        digit_exists = 0;
        all_correct = 1;
        for (i=0; i<4; i=i+1) begin
            checked_result[i] = 0;
            if (guess[i] == secret[i]) begin
                checked_result[i] = CORRECT;
                used_secret_positions[i] = 1;
            end else
                all_correct = 0;
        end
        for (j=0; j<4; j=j+1) begin
            if (checked_result[j] != CORRECT) begin
                found_available = 0;
                digit_exists = 0;
                for (k=0; k<4; k=k+1) begin
                    if (guess[j] == secret[k]) begin
                        digit_exists = 1;
                        if (!used_secret_positions[k] && !found_available) begin
                            used_secret_positions[k] = 1;
                            found_available = 1;
                        end
                    end
                end
                if (found_available) checked_result[j] = CLOSE;
                else if (digit_exists) checked_result[j] = NO_MORE;
                else checked_result[j] = NOT_HERE;
            end
        end
    end

    always @(posedge clk) begin
        if (reset || !active) begin
            state <= GENERATE;
            generated_count <= 0;
            generated_digits <= 0;
            confirmed_boxes <= 0;
            current_box <= 0;
            for (n=0; n<4; n=n+1) begin
                secret[n] <= 0;
                guess[n] <= 0;
                result[n] <= 0;
            end
        end else begin
            case (state)
                GENERATE: begin
                    // Fixed secret PIN: 1, 2, 4, 5 (left to right).
                    secret[0] <= 4'd1;
                    secret[1] <= 4'd2;
                    secret[2] <= 4'd4;
                    secret[3] <= 4'd5;
                    state <= ENTER_DIGITS;
                end
                ENTER_DIGITS: begin
                    if (scroll && !confirm) begin
                        if (guess[current_box] == 5)
                            guess[current_box] <= 0;
                        else
                            guess[current_box] <= guess[current_box] + 1'b1;
                    end else if (confirm && !scroll) begin
                        confirmed_boxes[current_box] <= 1;
                        if (current_box == 3)
                            state <= CHECK_GUESS;
                        else
                            current_box <= current_box + 1'b1;
                    end
                end
                CHECK_GUESS: begin
                    for (n=0; n<4; n=n+1)
                        result[n] <= checked_result[n];
                    if (all_correct) state <= SOLVED;
                    else state <= SHOW_FEEDBACK;
                end
                SHOW_FEEDBACK: begin
                    if (confirm && !scroll) begin
                        for (n=0; n<4; n=n+1) begin
                            guess[n] <= 0;
                            result[n] <= 0;
                        end
                        confirmed_boxes <= 0;
                        current_box <= 0;
                        state <= ENTER_DIGITS;
                    end
                end
                SOLVED: state <= SOLVED;
                default: state <= GENERATE;
            endcase
        end
    end
endmodule
