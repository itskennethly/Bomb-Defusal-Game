module CountdownTimer (
   input MAX10_CLK1_50,  //50 MHz clock from the FPGA
   input [1:0] KEY, // Two push buttons
   input enable, //Starts ir pause countdown
   output [7:0] HEX1, //First Segment Display
   output [7:0] HEX0, //Second Segment Display
   output reg bomb_exploded //FPGA Project reached 0 
);

    wire clk = MAX10_CLK1_50; //Clock Connection
    wire reset_sig = ~KEY[0]; //Reset signal when KEY0 is pressed becomes 1

   wire [12:0] seconds_left;
   wire time_up;
   wire expires_now;
   game_countdown #(
      .CLOCK_HZ(50000000),
        .START_SECONDS(60)
   ) timer (
      .clk(clk),
      .reset(reset_sig),
      .run(enable && !bomb_exploded),
      .seconds_left(seconds_left),
      .time_up(time_up),
      .expires_now(expires_now)
    );
    
   // Convert remaining seconds into decimal digits
    wire [3:0] tens;
    wire [3:0] ones;

    assign tens = seconds_left / 10;
    assign ones = seconds_left % 10;

    // Detect when countdown reaches zero
    always @(posedge clk or posedge reset_sig) begin
        if (reset_sig) begin
            bomb_exploded <= 0;
        end
        else if (expires_now || time_up) begin
            bomb_exploded <= 1;
        end
    end
SevenSegmentPatterns display_tens (
    .digit(tens),
    .HEX0(HEX1[6:0])
);

SevenSegmentPatterns display_ones (
    .digit(ones),
    .HEX0(HEX0[6:0])
);

assign HEX1[7] = 1'b1;
assign HEX0[7] = 1'b1;

endmodule
