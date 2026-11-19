module CountdownTimer #(
   parameter integer CLOCK_HZ = 50000000,
   parameter [12:0] START_SECONDS = 90
)(
   input clk, //50 MHz Clock
   input reset, //Reset Switch SW[9]
   input run, //Starts and pause countdown
   output reg [12:0] seconds_left, //Remaining time 
   output time_up, //High when countdown reaches 0
   output expires_now //High when it is at 0
);

    // Countdown registers
    reg [31:0] clock_count;

    // Status signals
    assign time_up = (seconds_left == 0);
    assign expires_now = run && (seconds_left == 1) && (clock_count == CLOCK_HZ - 1);

    // Countdown timer
    always @(posedge clk) begin
        if (reset) begin
            seconds_left <= START_SECONDS;
            clock_count <= 0;
        end
        else if (run && !time_up) begin
            if (clock_count == CLOCK_HZ - 1) begin
                seconds_left <= seconds_left - 1'b1;
                clock_count <= 0;
            end
            else
                clock_count <= clock_count + 1'b1;
            end
        end
endmodule
