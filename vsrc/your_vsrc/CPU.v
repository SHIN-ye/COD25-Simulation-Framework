`timescale 1ns / 1ps

module CPU (
    input         clk, rst,

    // IM interface
    output [31:0] inst_addr,
    input  [31:0] inst,

    // DM interface
    output        dmem_we,
    output [31:0] dmem_addr, dmem_wd,
    input  [31:0] dmem_rd,

    // debug
    input  [ 4:0] debug_reg_ra,
    output [31:0] debug_reg_rd
);

    // ============================================
    // IF stage
    // ============================================
    wire [31:0] pc_cur, pc_next;
    wire [31:0] pc_plus4_f = pc_cur + 32'd4;

    PC u_PC (
        .clk (clk),
        .rst (rst),
        .en  (1'b1),
        .npc (pc_next),
        .pc  (pc_cur)
    );

    assign inst_addr = pc_cur;

    // ============================================
    // IF/ID pipeline register
    // ============================================
    wire [31:0] pc_d, inst_d;
    wire        commit_d;
    wire        flush;

    IF_ID u_IF_ID (
        .clk     (clk),
        .rst     (rst),
        .flush   (flush),
        .pc_f    (pc_cur),
        .inst_f  (inst),
        .pc_d    (pc_d),
        .inst_d  (inst_d),
        .commit_d(commit_d)
    );

    // ============================================
    // ID stage
    // ============================================
    wire [ 4:0] alu_op_d;
    wire [31:0] imm_d;
    wire [ 4:0] rf_ra0_d, rf_ra1_d, rf_wa_d;
    wire        rf_we_d, alu_src0_sel_d, alu_src1_sel_d;
    wire [ 3:0] br_type_d, dmem_access_d;
    wire        dmem_we_d;
    wire [ 1:0] rf_wd_sel_d;

    decoder u_DECODE (
        .inst         (inst_d),
        .alu_op       (alu_op_d),
        .imm          (imm_d),
        .rf_ra0       (rf_ra0_d),
        .rf_ra1       (rf_ra1_d),
        .rf_wa        (rf_wa_d),
        .rf_we        (rf_we_d),
        .alu_src0_sel (alu_src0_sel_d),
        .alu_src1_sel (alu_src1_sel_d),
        .br_type      (br_type_d),
        .dmem_access  (dmem_access_d),
        .dmem_we      (dmem_we_d),
        .rf_wd_sel    (rf_wd_sel_d)
    );

    // Register file read (ID stage)
    wire [31:0] rf_rd0_d, rf_rd1_d;
    // Write-back signals
    wire [ 4:0] rf_wa_w;
    wire        rf_we_w;
    wire [31:0] rf_wd_w;
    wire        commit_w;

    regfiles u_RF (
        .clk         (clk),
        .rf_ra0      (rf_ra0_d),
        .rf_ra1      (rf_ra1_d),
        .rf_wa       (rf_wa_w),
        .rf_we       (rf_we_w & commit_w),
        .rf_wd       (rf_wd_w),
        .rf_rd0      (rf_rd0_d),
        .rf_rd1      (rf_rd1_d),
        .debug_reg_ra(debug_reg_ra),
        .debug_reg_rd(debug_reg_rd)
    );

    // ============================================
    // ID/EX pipeline register
    // ============================================
    wire [ 4:0] alu_op_e;
    wire [31:0] imm_e, rf_rd0_e, rf_rd1_e;
    wire [ 4:0] rf_wa_e;
    wire        rf_we_e, alu_src0_sel_e, alu_src1_sel_e;
    wire [ 3:0] br_type_e, dmem_access_e;
    wire        dmem_we_e;
    wire [ 1:0] rf_wd_sel_e;
    wire [31:0] pc_e;
    wire        commit_e;

    ID_EX u_ID_EX (
        .clk           (clk),
        .rst           (rst),
        .flush         (flush),
        .alu_op_d      (alu_op_d),
        .imm_d         (imm_d),
        .rf_rd0_d      (rf_rd0_d),
        .rf_rd1_d      (rf_rd1_d),
        .rf_wa_d       (rf_wa_d),
        .rf_we_d       (rf_we_d),
        .alu_src0_sel_d(alu_src0_sel_d),
        .alu_src1_sel_d(alu_src1_sel_d),
        .br_type_d     (br_type_d),
        .dmem_access_d (dmem_access_d),
        .dmem_we_d     (dmem_we_d),
        .rf_wd_sel_d   (rf_wd_sel_d),
        .pc_d          (pc_d),
        .commit_d      (commit_d),
        .alu_op_e      (alu_op_e),
        .imm_e         (imm_e),
        .rf_rd0_e      (rf_rd0_e),
        .rf_rd1_e      (rf_rd1_e),
        .rf_wa_e       (rf_wa_e),
        .rf_we_e       (rf_we_e),
        .alu_src0_sel_e(alu_src0_sel_e),
        .alu_src1_sel_e(alu_src1_sel_e),
        .br_type_e     (br_type_e),
        .dmem_access_e (dmem_access_e),
        .dmem_we_e     (dmem_we_e),
        .rf_wd_sel_e   (rf_wd_sel_e),
        .pc_e          (pc_e),
        .commit_e      (commit_e)
    );

    // ============================================
    // EX stage
    // ============================================
    wire [31:0] alu_src0_e, alu_src1_e;
    wire [31:0] alu_res;

    MUX #(.WIDTH(32)) u_MUX0 (
        .src0 (rf_rd0_e),
        .src1 (pc_e),
        .sel  (alu_src0_sel_e),
        .res  (alu_src0_e)
    );

    MUX #(.WIDTH(32)) u_MUX1 (
        .src0 (rf_rd1_e),
        .src1 (imm_e),
        .sel  (alu_src1_sel_e),
        .res  (alu_src1_e)
    );

    ALU u_ALU (
        .alu_src0 (alu_src0_e),
        .alu_src1 (alu_src1_e),
        .alu_op   (alu_op_e),
        .alu_res  (alu_res)
    );

    // Branch decision
    wire [1:0] npc_sel_e;
    BRANCH u_BRANCH (
        .br_type (br_type_e),
        .br_src0 (rf_rd0_e),
        .br_src1 (rf_rd1_e),
        .npc_sel (npc_sel_e)
    );

    // flush when branch/jump taken in EX
    assign flush = (npc_sel_e != 2'b00);

    // PC update: default PC+4, branch/JAL target, or JALR target
    wire [31:0] pc_add_imm = pc_e + imm_e;
    wire [31:0] pc_jalr    = {alu_res[31:1], 1'b0};
    wire [31:0] pc_plus4_e;

    assign pc_plus4_e = pc_e + 32'd4;

    assign pc_next = (npc_sel_e == 2'b10) ? pc_jalr :
                     (npc_sel_e == 2'b01) ? pc_add_imm :
                     pc_plus4_f;

    // ============================================
    // EX/MEM pipeline register
    // ============================================
    wire [31:0] alu_res_m, rf_rd1_m;
    wire [ 4:0] rf_wa_m;
    wire        rf_we_m;
    wire [ 3:0] dmem_access_m;
    wire        dmem_we_m;
    wire [ 1:0] rf_wd_sel_m;
    wire [31:0] pc_plus4_m;
    wire        commit_m;

    EX_MEM u_EX_MEM (
        .clk         (clk),
        .rst         (rst),
        .alu_res_e   (alu_res),
        .rf_rd1_e    (rf_rd1_e),
        .rf_wa_e     (rf_wa_e),
        .rf_we_e     (rf_we_e),
        .dmem_access_e(dmem_access_e),
        .dmem_we_e   (dmem_we_e),
        .rf_wd_sel_e (rf_wd_sel_e),
        .pc_plus4_e  (pc_plus4_e),
        .commit_e    (commit_e),
        .alu_res_m   (alu_res_m),
        .rf_rd1_m    (rf_rd1_m),
        .rf_wa_m     (rf_wa_m),
        .rf_we_m     (rf_we_m),
        .dmem_access_m(dmem_access_m),
        .dmem_we_m   (dmem_we_m),
        .rf_wd_sel_m (rf_wd_sel_m),
        .pc_plus4_m  (pc_plus4_m),
        .commit_m    (commit_m)
    );

    // ============================================
    // MEM stage
    // ============================================
    wire [31:0] slu_rd_out, slu_wd_out;

    assign dmem_addr = alu_res_m;
    assign dmem_we   = dmem_we_m & commit_m;
    assign dmem_wd   = slu_wd_out;

    SLU u_SLU (
        .addr        (alu_res_m),
        .dmem_access (dmem_access_m),
        .rd_in       (dmem_rd),
        .wd_in       (rf_rd1_m),
        .rd_out      (slu_rd_out),
        .wd_out      (slu_wd_out)
    );

    // ============================================
    // MEM/WB pipeline register
    // ============================================
    wire [31:0] alu_res_w, slu_rd_w;
    wire        rf_we_w_raw;
    wire [ 1:0] rf_wd_sel_w;
    wire [31:0] pc_plus4_w;

    MEM_WB u_MEM_WB (
        .clk        (clk),
        .rst        (rst),
        .alu_res_m  (alu_res_m),
        .slu_rd_m   (slu_rd_out),
        .rf_wa_m    (rf_wa_m),
        .rf_we_m    (rf_we_m),
        .rf_wd_sel_m(rf_wd_sel_m),
        .pc_plus4_m (pc_plus4_m),
        .commit_m   (commit_m),
        .alu_res_w  (alu_res_w),
        .slu_rd_w   (slu_rd_w),
        .rf_wa_w    (rf_wa_w),
        .rf_we_w    (rf_we_w_raw),
        .rf_wd_sel_w(rf_wd_sel_w),
        .pc_plus4_w (pc_plus4_w),
        .commit_w   (commit_w)
    );

    assign rf_we_w = rf_we_w_raw;

    // ============================================
    // WB stage — write-back MUX
    // ============================================
    MUX2 #(.WIDTH(32)) u_WB_MUX (
        .src0 (alu_res_w),
        .src1 (pc_plus4_w),
        .src2 (slu_rd_w),
        .src3 (32'b0),
        .sel  (rf_wd_sel_w),
        .res  (rf_wd_w)
    );

endmodule
