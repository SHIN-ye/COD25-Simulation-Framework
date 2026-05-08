`timescale 1ns / 1ps

module MUX #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1 : 0] src0,
    input  [WIDTH-1 : 0] src1,
    input                sel,
    output [WIDTH-1 : 0] res
);

    assign res = sel ? src1 : src0;

endmodule
