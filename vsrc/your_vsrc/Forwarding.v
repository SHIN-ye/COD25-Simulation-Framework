`timescale 1ns / 1ps

module Forwarding (
    input  [ 4:0] rf_wa_mem,
    input         rf_we_mem,
    input  [31:0] alu_res_mem,

    input  [ 4:0] rf_wa_wb,
    input         rf_we_wb,
    input  [31:0] rf_wd_wb,

    input  [ 4:0] rf_ra0_ex,
    input  [ 4:0] rf_ra1_ex,

    output        rf_rd0_fe,
    output [31:0] rf_rd0_fd,
    output        rf_rd1_fe,
    output [31:0] rf_rd1_fd
);

    wire mem_match_0 = rf_we_mem && (rf_wa_mem != 5'b0) && (rf_wa_mem == rf_ra0_ex);
    wire mem_match_1 = rf_we_mem && (rf_wa_mem != 5'b0) && (rf_wa_mem == rf_ra1_ex);
    wire wb_match_0  = rf_we_wb  && (rf_wa_wb  != 5'b0) && (rf_wa_wb  == rf_ra0_ex);
    wire wb_match_1  = rf_we_wb  && (rf_wa_wb  != 5'b0) && (rf_wa_wb  == rf_ra1_ex);

    assign rf_rd0_fe = mem_match_0 | wb_match_0;
    assign rf_rd1_fe = mem_match_1 | wb_match_1;

    assign rf_rd0_fd = mem_match_0 ? alu_res_mem : rf_wd_wb;
    assign rf_rd1_fd = mem_match_1 ? alu_res_mem : rf_wd_wb;

endmodule
