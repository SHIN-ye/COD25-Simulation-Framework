`timescale 1ns / 1ps

module EX_MEM (
    input         clk, rst,
    input  [31:0] alu_res_e, rf_rd1_e,
    input  [ 4:0] rf_wa_e,
    input         rf_we_e,
    input  [ 3:0] dmem_access_e,
    input         dmem_we_e,
    input  [ 1:0] rf_wd_sel_e,
    input  [31:0] pc_plus4_e,
    input         commit_e,
    // to MEM stage
    output reg [31:0] alu_res_m, rf_rd1_m,
    output reg [ 4:0] rf_wa_m,
    output reg        rf_we_m,
    output reg [ 3:0] dmem_access_m,
    output reg        dmem_we_m,
    output reg [ 1:0] rf_wd_sel_m,
    output reg [31:0] pc_plus4_m,
    output reg        commit_m
);
    always @(posedge clk) begin
        if (rst) begin
            alu_res_m     <= 32'b0;
            rf_rd1_m      <= 32'b0;
            rf_wa_m       <= 5'b0;
            rf_we_m       <= 1'b0;
            dmem_access_m <= 4'd0;
            dmem_we_m     <= 1'b0;
            rf_wd_sel_m   <= 2'b0;
            pc_plus4_m    <= 32'b0;
            commit_m      <= 1'b0;
        end else begin
            alu_res_m     <= alu_res_e;
            rf_rd1_m      <= rf_rd1_e;
            rf_wa_m       <= rf_wa_e;
            rf_we_m       <= rf_we_e;
            dmem_access_m <= dmem_access_e;
            dmem_we_m     <= dmem_we_e;
            rf_wd_sel_m   <= rf_wd_sel_e;
            pc_plus4_m    <= pc_plus4_e;
            commit_m      <= commit_e;
        end
    end
endmodule
