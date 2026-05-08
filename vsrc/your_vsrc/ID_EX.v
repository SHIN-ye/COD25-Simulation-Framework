`timescale 1ns / 1ps

module ID_EX (
    input         clk, rst, flush,
    // from ID stage
    input  [ 4:0] alu_op_d,
    input  [31:0] imm_d, rf_rd0_d, rf_rd1_d,
    input  [ 4:0] rf_wa_d,
    input         rf_we_d, alu_src0_sel_d, alu_src1_sel_d,
    input  [ 3:0] br_type_d, dmem_access_d,
    input         dmem_we_d,
    input  [ 1:0] rf_wd_sel_d,
    input  [31:0] pc_d, inst_d,
    input         commit_d, halt_d,
    // to EX stage
    output reg [ 4:0] alu_op_e,
    output reg [31:0] imm_e, rf_rd0_e, rf_rd1_e,
    output reg [ 4:0] rf_wa_e,
    output reg        rf_we_e, alu_src0_sel_e, alu_src1_sel_e,
    output reg [ 3:0] br_type_e, dmem_access_e,
    output reg        dmem_we_e,
    output reg [ 1:0] rf_wd_sel_e,
    output reg [31:0] pc_e, inst_e,
    output reg        commit_e, halt_e
);
    always @(posedge clk) begin
        if (rst | flush) begin
            alu_op_e       <= 5'b0;
            imm_e          <= 32'b0;
            rf_rd0_e       <= 32'b0;
            rf_rd1_e       <= 32'b0;
            rf_wa_e        <= 5'b0;
            rf_we_e        <= 1'b0;
            alu_src0_sel_e <= 1'b0;
            alu_src1_sel_e <= 1'b0;
            br_type_e      <= 4'd0;
            dmem_access_e  <= 4'd0;
            dmem_we_e      <= 1'b0;
            rf_wd_sel_e    <= 2'b0;
            pc_e           <= 32'b0;
            inst_e         <= 32'b0;
            commit_e       <= 1'b0;
            halt_e         <= 1'b0;
        end else begin
            alu_op_e       <= alu_op_d;
            imm_e          <= imm_d;
            rf_rd0_e       <= rf_rd0_d;
            rf_rd1_e       <= rf_rd1_d;
            rf_wa_e        <= rf_wa_d;
            rf_we_e        <= rf_we_d;
            alu_src0_sel_e <= alu_src0_sel_d;
            alu_src1_sel_e <= alu_src1_sel_d;
            br_type_e      <= br_type_d;
            dmem_access_e  <= dmem_access_d;
            dmem_we_e      <= dmem_we_d;
            rf_wd_sel_e    <= rf_wd_sel_d;
            pc_e           <= pc_d;
            inst_e         <= inst_d;
            commit_e       <= commit_d;
            halt_e         <= halt_d;
        end
    end
endmodule
