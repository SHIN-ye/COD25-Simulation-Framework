`timescale 1ns / 1ps

module BRANCH(
    input  [ 3 : 0] br_type,
    input  [31 : 0] br_src0,
    input  [31 : 0] br_src1,
    output [ 1 : 0] npc_sel
);

    // RV32I 分支类型定义
    `define NO_BRANCH 4'd0
    `define BR_BEQ    4'd1
    `define BR_BNE    4'd2
    `define BR_BLT    4'd3
    `define BR_BGE    4'd4
    `define BR_BLTU   4'd5
    `define BR_BGEU   4'd6
    `define BR_JAL    4'd7
    `define BR_JALR   4'd8

    wire signed [31:0] signed_src0 = br_src0;
    wire signed [31:0] signed_src1 = br_src1;

    reg jump;

    always @(*) begin
        case(br_type)
            `BR_BEQ:  jump = (br_src0 == br_src1);
            `BR_BNE:  jump = (br_src0 != br_src1);
            `BR_BLT:  jump = (signed_src0 < signed_src1);
            `BR_BGE:  jump = (signed_src0 >= signed_src1);
            `BR_BLTU: jump = (br_src0 < br_src1);
            `BR_BGEU: jump = (br_src0 >= br_src1);
            `BR_JAL, `BR_JALR: jump = 1'b1;
            default:  jump = 1'b0;
        endcase
    end

    // npc_sel: 00=PC+4, 01=跳转(PC+IMM), 10=JALR(寄存器值+IMM)
    assign npc_sel = (br_type == `BR_JALR) ? 2'b10 : 
                     (jump ? 2'b01 : 2'b00);

endmodule
