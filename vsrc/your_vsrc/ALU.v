`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/02 19:20:07
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`define ADD                 5'b00000    
`define SUB                 5'b00010   
`define SLT                 5'b00100
`define SLTU                5'b00101
`define AND                 5'b01001
`define OR                  5'b01010
`define XOR                 5'b01011
`define SLL                 5'b01110   
`define SRL                 5'b01111    
`define SRA                 5'b10000  
`define SRC0                5'b10001
`define SRC1                5'b10010

module ALU (
    input      [31:0] alu_src0,
    input      [31:0] alu_src1,
    input      [ 4:0] alu_op,

    output reg [31:0] alu_res
);

    always @(*) begin
        case(alu_op)
            `ADD  : alu_res = alu_src0 + alu_src1;
            `SUB  : alu_res = alu_src0 - alu_src1;
            `SLT  : alu_res = $signed(alu_src0) < $signed(alu_src1) ? 32'b1 : 32'b0;
            `SLTU : alu_res = alu_src0 < alu_src1 ? 32'b1 : 32'b0;
            `AND  : alu_res = alu_src0 & alu_src1;
            `OR   : alu_res = alu_src0 | alu_src1;
            `XOR  : alu_res = alu_src0 ^ alu_src1;
            `SLL  : alu_res = alu_src0 << alu_src1[4:0];     // 逻辑左移只需要取后5位作为移位量
            `SRL  : alu_res = alu_src0 >> alu_src1[4:0];     // 逻辑右移
            `SRA  : alu_res = $signed(alu_src0) >>> alu_src1[4:0]; // 算术右移
            `SRC0 : alu_res = alu_src0;
            `SRC1 : alu_res = alu_src1;
            default : alu_res = 32'h0;
        endcase
    end
    
endmodule
