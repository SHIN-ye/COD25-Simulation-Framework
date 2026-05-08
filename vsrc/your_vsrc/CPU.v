`timescale 1ns / 1ps

module CPU (
    input         clk,
    input         rst,
    input         global_en,

    // im
    output [31:0] imem_raddr,
    input  [31:0] imem_rdata,

    // dm
    output        dmem_we,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    input  [31:0] dmem_rdata,

    output        commit,
    output [31:0] commit_pc,
    output [31:0] commit_instr,
    output        commit_halt,
    output        commit_reg_we,
    output [ 4:0] commit_reg_wa,
    output [31:0] commit_reg_wd,
    output        commit_dmem_we,
    output [31:0] commit_dmem_wa,
    output [31:0] commit_dmem_wd,

    // debug
    input  [ 4:0] debug_reg_ra,
    output [31:0] debug_reg_rd
);

    localparam [31:0] HALT_INST = 32'h00100073;

    wire [31:0] pc_cur;
    wire [31:0] pc_next;
    wire [31:0] pc_real_next; // 分支模块算出的实际下一个PC
    
    // Decoder译码器输出线
    wire [ 4:0] alu_op;
    wire [31:0] imm;
    wire [ 4:0] rf_ra0, rf_ra1, rf_wa;
    wire        rf_we, alu_src0_sel, alu_src1_sel;
    wire [ 3:0] br_type;
    wire [ 3:0] dmem_access;
    wire [ 1:0] rf_wd_sel;
    
    // RF与MUX数据流线
    wire [31:0] rf_rd0, rf_rd1;
    wire [31:0] alu_src0, alu_src1;
    wire [31:0] alu_res;

    // 新增的信号线
    wire [ 1:0] npc_sel;
    wire [31:0] pc_add_imm = pc_cur + imm;
    wire [31:0] pc_jalr = {alu_res[31:1], 1'b0}; // RV32I指令集：JALR将最低位置0
    wire [31:0] slu_rd_out;
    wire [31:0] rf_wd_data;

    wire        dmem_we_raw;
    wire [31:0] dmem_wd_raw;
    wire        rf_we_raw;

    wire        commit_raw;
    wire [31:0] commit_pc_raw;
    wire [31:0] commit_instr_raw;
    wire        commit_halt_raw;
    wire        commit_reg_we_raw;
    wire [ 4:0] commit_reg_wa_raw;
    wire [31:0] commit_reg_wd_raw;
    wire        commit_dmem_we_raw;
    wire [31:0] commit_dmem_wa_raw;
    wire [31:0] commit_dmem_wd_raw;

    reg         commit_reg;
    reg  [31:0] commit_pc_reg;
    reg  [31:0] commit_instr_reg;
    reg         commit_halt_reg;
    reg         commit_reg_we_reg;
    reg  [ 4:0] commit_reg_wa_reg;
    reg  [31:0] commit_reg_wd_reg;
    reg         commit_dmem_we_reg;
    reg  [31:0] commit_dmem_wa_reg;
    reg  [31:0] commit_dmem_wd_reg;

    assign imem_raddr = pc_cur;
    assign dmem_addr = alu_res;
    assign dmem_wdata = dmem_wd_raw;
    assign dmem_we = dmem_we_raw & global_en;
    
    assign commit_raw = global_en & ~rst;
    assign commit_pc_raw = pc_cur;
    assign commit_instr_raw = imem_rdata;
    assign commit_halt_raw = (imem_rdata == HALT_INST);
    assign commit_reg_we_raw = rf_we_raw;
    assign commit_reg_wa_raw = rf_wa;
    assign commit_reg_wd_raw = rf_wd_data;
    assign commit_dmem_we_raw = dmem_we_raw;
    assign commit_dmem_wa_raw = alu_res;
    assign commit_dmem_wd_raw = dmem_wd_raw;

    always @(posedge clk) begin
        if (rst) begin
            commit_reg <= 1'b0;
            commit_pc_reg <= 32'b0;
            commit_instr_reg <= 32'b0;
            commit_halt_reg <= 1'b0;
            commit_reg_we_reg <= 1'b0;
            commit_reg_wa_reg <= 5'b0;
            commit_reg_wd_reg <= 32'b0;
            commit_dmem_we_reg <= 1'b0;
            commit_dmem_wa_reg <= 32'b0;
            commit_dmem_wd_reg <= 32'b0;
        end
        else if (global_en) begin
            commit_reg <= commit_raw;
            commit_pc_reg <= commit_pc_raw;
            commit_instr_reg <= commit_instr_raw;
            commit_halt_reg <= commit_halt_raw;
            commit_reg_we_reg <= commit_reg_we_raw;
            commit_reg_wa_reg <= commit_reg_wa_raw;
            commit_reg_wd_reg <= commit_reg_wd_raw;
            commit_dmem_we_reg <= commit_dmem_we_raw;
            commit_dmem_wa_reg <= commit_dmem_wa_raw;
            commit_dmem_wd_reg <= commit_dmem_wd_raw;
        end
    end

    assign commit = commit_reg;
    assign commit_pc = commit_pc_reg;
    assign commit_instr = commit_instr_reg;
    assign commit_halt = commit_halt_reg;
    assign commit_reg_we = commit_reg_we_reg;
    assign commit_reg_wa = commit_reg_wa_reg;
    assign commit_reg_wd = commit_reg_wd_reg;
    assign commit_dmem_we = commit_dmem_we_reg;
    assign commit_dmem_wa = commit_dmem_wa_reg;
    assign commit_dmem_wd = commit_dmem_wd_reg;
    
    // PC + 4
    assign pc_next = pc_cur + 32'h4;


    // 例化部分

    // 1. NPC 选择器 (4选1)
    MUX2 #(.WIDTH(32)) u_NPC_MUX (
        .src0 (pc_next),
        .src1 (pc_add_imm),
        .src2 (pc_jalr),
        .src3 (32'b0),
        .sel  (npc_sel),
        .res  (pc_real_next)
    );

    PC u_PC (
        .clk (clk),
        .rst (rst),
        .en  (global_en),
        .npc (pc_real_next),
        .pc  (pc_cur)
    );

    decoder u_DECODE (
        .inst        (imem_rdata),
        .alu_op      (alu_op),
        .imm         (imm),
        .rf_ra0      (rf_ra0),
        .rf_ra1      (rf_ra1),
        .rf_wa       (rf_wa),
        .rf_we       (rf_we_raw),
        .alu_src0_sel(alu_src0_sel),
        .alu_src1_sel(alu_src1_sel),
        .br_type     (br_type),
        .dmem_access (dmem_access),
        .dmem_we     (dmem_we_raw),
        .rf_wd_sel   (rf_wd_sel)
    );

    BRANCH u_BRANCH (
        .br_type (br_type),
        .br_src0 (rf_rd0),
        .br_src1 (rf_rd1),
        .npc_sel (npc_sel)
    );

    regfiles u_RF (
        .clk         (clk),
        .rf_ra0      (rf_ra0),
        .rf_ra1      (rf_ra1),
        .rf_wa       (rf_wa),
        .rf_we       (rf_we_raw & global_en),
        .rf_wd       (rf_wd_data),   // 写回数据改成由 rf_wd_mux 提供
        .rf_rd0      (rf_rd0),
        .rf_rd1      (rf_rd1),
        .debug_reg_ra(debug_reg_ra), 
        .debug_reg_rd(debug_reg_rd)
    );

    MUX #(.WIDTH(32)) u_MUX0 (
        .src0 (rf_rd0),
        .src1 (pc_cur),            
        .sel  (alu_src0_sel),
        .res  (alu_src0)
    );

    MUX #(.WIDTH(32)) u_MUX1 (
        .src0 (rf_rd1),
        .src1 (imm),            
        .sel  (alu_src1_sel),
        .res  (alu_src1)
    );

    ALU u_ALU (
        .alu_src0 (alu_src0),
        .alu_src1 (alu_src1),
        .alu_op   (alu_op),
        .alu_res  (alu_res)
    );

    SLU u_SLU (
        .addr        (alu_res),
        .dmem_access (dmem_access),
        .rd_in       (dmem_rdata),
        .wd_in       (rf_rd1),
        .rd_out      (slu_rd_out),
        .wd_out      (dmem_wd_raw)
    );

    MUX2 #(.WIDTH(32)) u_RF_WD_MUX (
        .src0 (alu_res),
        .src1 (pc_next),
        .src2 (slu_rd_out),
        .src3 (32'b0),
        .sel  (rf_wd_sel),
        .res  (rf_wd_data)
    );

endmodule
