`timescale 1ns / 1ps

module PipelineControl (
    input         ex_rf_we,
    input  [ 1:0] ex_rf_wd_sel,
    input  [ 4:0] ex_rf_wa,
    input  [ 4:0] id_rf_ra0,
    input  [ 4:0] id_rf_ra1,
    input  [ 1:0] ex_npc_sel,
    input         global_en,

    output        pc_stall,
    output        if_id_stall,
    output        if_id_flush,
    output        id_ex_flush
);

    wire load_use = ex_rf_wd_sel == 2'b10
                 && ex_rf_we
                 && ex_rf_wa != 5'b0
                 && (id_rf_ra0 == ex_rf_wa || id_rf_ra1 == ex_rf_wa);

    wire branch_taken = ex_npc_sel != 2'b00;

    assign pc_stall    = global_en && load_use && !branch_taken;
    assign if_id_stall = global_en && load_use && !branch_taken;
    assign if_id_flush = global_en && branch_taken;
    assign id_ex_flush = global_en && (load_use || branch_taken);

endmodule
