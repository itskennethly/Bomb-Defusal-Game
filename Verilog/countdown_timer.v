module countdown_timer (
   input MAX10_CLK1_50,  //50 MHz clock from the FPGA
   input [1:0] KEY, // Two push buttons
   input enable, //Starts ir pause countdown
   output [7:0] HEX1, //First Segment Display
   output [7:0] HEX0, //Second Segment Display
   output reg bomb_exploded //FPGA Project reached 0 
);

    wire clk = MAX10_CLK1_50; //Clock Connection
    wire reset_sig = ~KEY[0]; //Reset signal when KEY0 is pressed becomes 1

    reg [25:0] clk_div_counter = 0; //Counts clock cycles
    reg clk_1hz = 0; // Stores the slower clock
        
    
        always @(posedge clk) begin
        if (clk_div_counter >= 24999999) begin
            clk_div_counter <= 0;
            clk_1hz <= ~clk_1hz;
        end else begin
            clk_div_counter <= clk_div_counter + 1;
        end
    end
    /*By changing the d_ number values you change whats in the tens and ones place 
    so that means if its d9 it would start at 90 for this*/
    reg[3:0] tens = 4'd6;  
    reg[3:0] ones = 4'd0;

    always @(posedge clk_1hz or posedge reset_sig) begin
    if(reset_sig)begin
        tens <= 4'd6;
        ones <=4'd0;
        bomb_exploded <= 0;
    end
    else if (enable && !bomb_exploded) begin
        if (tens == 0 && ones == 0) begin
            bomb_exploded <= 1;
        end
        else if (ones == 0) begin
            tens <= tens -1;
            ones <= 9;
        end
        else begin
            ones <= ones -1;
        end
    end
end
