module SevenSegmentPatterns(digit, HEX0);
    input [3:0] digit;
    output [6:0] HEX0;

    assign HEX0[0] = (~digit[3] & ~digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & ~digit[1] & ~digit[0]) |
                     (digit[3] & ~digit[2] & digit[1] & digit[0]) |
                     (digit[3] & digit[2] & ~digit[1] & digit[0]);

    assign HEX0[1] = (~digit[3] & digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & digit[1] & ~digit[0]) |
                     (digit[3] & ~digit[2] & digit[1] & digit[0]) |
                     (digit[3] & digit[2] & ~digit[1] & ~digit[0]) |
                     (digit[3] & digit[2] & digit[1] & ~digit[0]) |
                     (digit[3] & digit[2] & digit[1] & digit[0]);

    assign HEX0[2] = (~digit[3] & ~digit[2] & digit[1] & ~digit[0]) |
                     (digit[3] & digit[2] & ~digit[1] & ~digit[0]) |
                     (digit[3] & digit[2] & digit[1] & ~digit[0]) |
                     (digit[3] & digit[2] & digit[1] & digit[0]);

    assign HEX0[3] = (~digit[3] & ~digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & ~digit[1] & ~digit[0]) |
                     (~digit[3] & digit[2] & digit[1] & digit[0]) |
                     (digit[3] & ~digit[2] & digit[1] & ~digit[0]) |
                     (digit[3] & digit[2] & digit[1] & digit[0]);

    assign HEX0[4] = (~digit[3] & ~digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & ~digit[2] & digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & ~digit[1] & ~digit[0]) |
                     (~digit[3] & digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & digit[1] & digit[0]) |
                     (digit[3] & ~digit[2] & ~digit[1] & digit[0]);

    assign HEX0[5] = (~digit[3] & ~digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & ~digit[2] & digit[1] & ~digit[0]) |
                     (~digit[3] & ~digit[2] & digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & digit[1] & digit[0]) |
                     (digit[3] & digit[2] & ~digit[1] & digit[0]);

    assign HEX0[6] = (~digit[3] & ~digit[2] & ~digit[1] & ~digit[0]) |
                     (~digit[3] & ~digit[2] & ~digit[1] & digit[0]) |
                     (~digit[3] & digit[2] & digit[1] & digit[0]) |
                     (digit[3] & digit[2] & ~digit[1] & ~digit[0]);

endmodule
