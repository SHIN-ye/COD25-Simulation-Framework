`timescale 1ns / 1ps

module MEM_WB (
    input         clk, rst,
    input  [31:0] alu_res_m, slu_rd_m, dmem_wd_m,
    input  [ 4:0] rf_wa_m,
    input         rf_we_m, dmem_we_m,
    input  [ 1:0] rf_wd_sel_m,
    input  [31:0] pc_plus4_m, pc_m, inst_m,
    input         commit_m, halt_m,
    // to WB stage
    output reg [31:0] alu_res_w, slu_rd_w, dmem_wd_w,
    output reg [ 4:0] rf_wa_w,
    output reg        rf_we_w, dmem_we_w,
    output reg [ 1:0] rf_wd_sel_w,
    output reg [31:0] pc_plus4_w, pc_w, inst_w,
    output reg        commit_w, halt_w
);
    always @(posedge clk) begin
        if (rst) begin
            alu_res_w   <= 32'b0;
            slu_rd_w    <= 32'b0;
            dmem_wd_w   <= 32'b0;
            rf_wa_w     <= 5'b0;
            rf_we_w     <= 1'b0;
            dmem_we_w   <= 1'b0;
            rf_wd_sel_w <= 2'b0;
            pc_plus4_w  <= 32'b0;
            pc_w        <= 32'b0;
            inst_w      <= 32'b0;
            commit_w    <= 1'b0;
            halt_w      <= 1'b0;
        end else begin
            alu_res_w   <= alu_res_m;
            slu_rd_w    <= slu_rd_m;
            dmem_wd_w   <= dmem_wd_m;
            rf_wa_w     <= rf_wa_m;
            rf_we_w     <= rf_we_m;
            dmem_we_w   <= dmem_we_m;
            rf_wd_sel_w <= rf_wd_sel_m;
            pc_plus4_w  <= pc_plus4_m;
            pc_w        <= pc_m;
            inst_w      <= inst_m;
            commit_w    <= commit_m;
            halt_w      <= halt_m;
        end
    end
endmodule
