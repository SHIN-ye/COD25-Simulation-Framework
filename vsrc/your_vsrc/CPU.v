`timescale 1ns / 1ps

module CPU (
    input                   [ 0 : 0]            clk,
    input                   [ 0 : 0]            rst,
    input                   [ 0 : 0]            global_en,

    // IM interface
    output                  [31 : 0]            imem_raddr,
    input                   [31 : 0]            imem_rdata,

    // DM interface
    output                  [ 0 : 0]            dmem_we,
    output                  [31 : 0]            dmem_addr,
    output                  [31 : 0]            dmem_wdata,
    input                   [31 : 0]            dmem_rdata,

    // Debug
    output                  [ 0 : 0]            commit,
    output                  [31 : 0]            commit_pc,
    output                  [31 : 0]            commit_instr,
    output                  [ 0 : 0]            commit_halt,
    output                  [ 0 : 0]            commit_reg_we,
    output                  [ 4 : 0]            commit_reg_wa,
    output                  [31 : 0]            commit_reg_wd,
    output                  [ 0 : 0]            commit_dmem_we,
    output                  [31 : 0]            commit_dmem_wa,
    output                  [31 : 0]            commit_dmem_wd,

    input                   [ 4 : 0]            debug_reg_ra,
    output                  [31 : 0]            debug_reg_rd
);

    // ============================================
    // IF stage
    // ============================================
    wire [31:0] pc_cur, pc_next;
    wire [31:0] pc_plus4_f = pc_cur + 32'd4;

    wire        pc_stall;
    wire        if_id_stall, if_id_flush;
    wire        id_ex_flush;

    PC u_PC (
        .clk   (clk),
        .rst   (rst),
        .en    (global_en),
        .stall (pc_stall),
        .npc   (pc_next),
        .pc    (pc_cur)
    );

    assign imem_raddr = pc_cur;

    // ============================================
    // IF/ID pipeline register
    // ============================================
    wire [31:0] pc_d, inst_d;
    wire        commit_d;

    IF_ID u_IF_ID (
        .clk      (clk),
        .rst      (rst),
        .en       (global_en),
        .stall    (if_id_stall),
        .flush    (if_id_flush),
        .pc_f     (pc_cur),
        .inst_f   (imem_rdata),
        .pc_d     (pc_d),
        .inst_d   (inst_d),
        .commit_d (commit_d)
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
    wire        halt_d;

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
        .halt         (halt_d),
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
    wire [31:0] imm_e, rf_rd0_raw_e, rf_rd1_raw_e;
    wire [ 4:0] rf_wa_e, rf_ra0_e, rf_ra1_e;
    wire        rf_we_e, alu_src0_sel_e, alu_src1_sel_e;
    wire [ 3:0] br_type_e, dmem_access_e;
    wire        dmem_we_e;
    wire [ 1:0] rf_wd_sel_e;
    wire [31:0] pc_e, inst_e;
    wire        commit_e;
    wire        halt_e;

    ID_EX u_ID_EX (
        .clk            (clk),
        .rst            (rst),
        .en             (global_en),
        .stall          (1'b0),
        .flush          (id_ex_flush),
        .alu_op_d       (alu_op_d),
        .imm_d          (imm_d),
        .rf_rd0_d       (rf_rd0_d),
        .rf_rd1_d       (rf_rd1_d),
        .rf_wa_d        (rf_wa_d),
        .rf_ra0_d       (rf_ra0_d),
        .rf_ra1_d       (rf_ra1_d),
        .rf_we_d        (rf_we_d),
        .alu_src0_sel_d (alu_src0_sel_d),
        .alu_src1_sel_d (alu_src1_sel_d),
        .br_type_d      (br_type_d),
        .dmem_access_d  (dmem_access_d),
        .dmem_we_d      (dmem_we_d),
        .rf_wd_sel_d    (rf_wd_sel_d),
        .pc_d           (pc_d),
        .inst_d         (inst_d),
        .halt_d         (halt_d),
        .commit_d       (commit_d),
        .alu_op_e       (alu_op_e),
        .imm_e          (imm_e),
        .rf_rd0_e       (rf_rd0_raw_e),
        .rf_rd1_e       (rf_rd1_raw_e),
        .rf_wa_e        (rf_wa_e),
        .rf_ra0_e       (rf_ra0_e),
        .rf_ra1_e       (rf_ra1_e),
        .rf_we_e        (rf_we_e),
        .alu_src0_sel_e (alu_src0_sel_e),
        .alu_src1_sel_e (alu_src1_sel_e),
        .br_type_e      (br_type_e),
        .dmem_access_e  (dmem_access_e),
        .dmem_we_e      (dmem_we_e),
        .rf_wd_sel_e    (rf_wd_sel_e),
        .pc_e           (pc_e),
        .inst_e         (inst_e),
        .halt_e         (halt_e),
        .commit_e       (commit_e)
    );

    // ============================================
    // EX stage — forwarding
    // ============================================
    wire        rf_rd0_fe, rf_rd1_fe;
    wire [31:0] rf_rd0_fd, rf_rd1_fd;

    Forwarding u_Forwarding (
        .rf_wa_mem   (rf_wa_m),
        .rf_we_mem   (rf_we_m),
        .alu_res_mem (alu_res_m),
        .rf_wa_wb    (rf_wa_w),
        .rf_we_wb    (rf_we_w),
        .rf_wd_wb    (rf_wd_w),
        .rf_ra0_ex   (rf_ra0_e),
        .rf_ra1_ex   (rf_ra1_e),
        .rf_rd0_fe   (rf_rd0_fe),
        .rf_rd0_fd   (rf_rd0_fd),
        .rf_rd1_fe   (rf_rd1_fe),
        .rf_rd1_fd   (rf_rd1_fd)
    );

    // Forwarded register values (or raw if no forward)
    wire [31:0] rf_rd0_e = rf_rd0_fe ? rf_rd0_fd : rf_rd0_raw_e;
    wire [31:0] rf_rd1_e = rf_rd1_fe ? rf_rd1_fd : rf_rd1_raw_e;

    // ============================================
    // EX stage — ALU & branch
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

    // Pipeline control — stall/flush
    PipelineControl u_PipelineControl (
        .ex_rf_we     (rf_we_e),
        .ex_rf_wd_sel (rf_wd_sel_e),
        .ex_rf_wa     (rf_wa_e),
        .id_rf_ra0    (rf_ra0_d),
        .id_rf_ra1    (rf_ra1_d),
        .ex_npc_sel   (npc_sel_e),
        .global_en    (global_en),
        .pc_stall     (pc_stall),
        .if_id_stall  (if_id_stall),
        .if_id_flush  (if_id_flush),
        .id_ex_flush  (id_ex_flush)
    );

    // PC update: default PC+4, branch/JAL target, or JALR target
    wire [31:0] pc_add_imm = pc_e + imm_e;
    wire [31:0] pc_jalr    = {alu_res[31:1], 1'b0};
    wire [31:0] pc_plus4_e = pc_e + 32'd4;

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
    wire [31:0] pc_plus4_m, pc_m, inst_m;
    wire        commit_m;
    wire        halt_m;

    EX_MEM u_EX_MEM (
        .clk           (clk),
        .rst           (rst),
        .alu_res_e     (alu_res),
        .rf_rd1_e      (rf_rd1_e),
        .rf_wa_e       (rf_wa_e),
        .rf_we_e       (rf_we_e),
        .dmem_access_e (dmem_access_e),
        .dmem_we_e     (dmem_we_e),
        .rf_wd_sel_e   (rf_wd_sel_e),
        .pc_plus4_e    (pc_plus4_e),
        .pc_e          (pc_e),
        .inst_e        (inst_e),
        .commit_e      (commit_e),
        .halt_e        (halt_e),
        .alu_res_m     (alu_res_m),
        .rf_rd1_m      (rf_rd1_m),
        .rf_wa_m       (rf_wa_m),
        .rf_we_m       (rf_we_m),
        .dmem_access_m (dmem_access_m),
        .dmem_we_m     (dmem_we_m),
        .rf_wd_sel_m   (rf_wd_sel_m),
        .pc_plus4_m    (pc_plus4_m),
        .pc_m          (pc_m),
        .inst_m        (inst_m),
        .commit_m      (commit_m),
        .halt_m        (halt_m)
    );

    // ============================================
    // MEM stage
    // ============================================
    wire [31:0] slu_rd_out, slu_wd_out;

    assign dmem_addr  = alu_res_m;
    assign dmem_we    = dmem_we_m & commit_m;
    assign dmem_wdata = slu_wd_out;

    SLU u_SLU (
        .addr        (alu_res_m),
        .dmem_access (dmem_access_m),
        .rd_in       (dmem_rdata),
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
    wire [31:0] pc_plus4_w, pc_w, inst_w;
    wire        halt_w;
    wire        dmem_we_w;
    wire [31:0] dmem_wd_w;

    MEM_WB u_MEM_WB (
        .clk         (clk),
        .rst         (rst),
        .alu_res_m   (alu_res_m),
        .slu_rd_m    (slu_rd_out),
        .dmem_wd_m   (slu_wd_out),
        .rf_wa_m     (rf_wa_m),
        .rf_we_m     (rf_we_m),
        .dmem_we_m   (dmem_we_m),
        .rf_wd_sel_m (rf_wd_sel_m),
        .pc_plus4_m  (pc_plus4_m),
        .pc_m        (pc_m),
        .inst_m      (inst_m),
        .commit_m    (commit_m),
        .halt_m      (halt_m),
        .alu_res_w   (alu_res_w),
        .slu_rd_w    (slu_rd_w),
        .dmem_wd_w   (dmem_wd_w),
        .rf_wa_w     (rf_wa_w),
        .rf_we_w     (rf_we_w_raw),
        .dmem_we_w   (dmem_we_w),
        .rf_wd_sel_w (rf_wd_sel_w),
        .pc_plus4_w  (pc_plus4_w),
        .pc_w        (pc_w),
        .inst_w      (inst_w),
        .commit_w    (commit_w),
        .halt_w      (halt_w)
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

    // ============================================
    // Commit regs (暂存一级后输出，同步比对时序)
    // ============================================
    reg  [ 0 : 0]   commit_reg;
    reg  [31 : 0]   commit_pc_reg;
    reg  [31 : 0]   commit_instr_reg;
    reg  [ 0 : 0]   commit_halt_reg;
    reg  [ 0 : 0]   commit_reg_we_reg;
    reg  [ 4 : 0]   commit_reg_wa_reg;
    reg  [31 : 0]   commit_reg_wd_reg;
    reg  [ 0 : 0]   commit_dmem_we_reg;
    reg  [31 : 0]   commit_dmem_wa_reg;
    reg  [31 : 0]   commit_dmem_wd_reg;

    always @(posedge clk) begin
        if (rst) begin
            commit_reg          <= 1'H0;
            commit_pc_reg       <= 32'H0;
            commit_instr_reg    <= 32'H0;
            commit_halt_reg     <= 1'H0;
            commit_reg_we_reg   <= 1'H0;
            commit_reg_wa_reg   <= 5'H0;
            commit_reg_wd_reg   <= 32'H0;
            commit_dmem_we_reg  <= 1'H0;
            commit_dmem_wa_reg  <= 32'H0;
            commit_dmem_wd_reg  <= 32'H0;
        end
        else if (global_en) begin
            commit_reg          <= commit_w;
            commit_pc_reg       <= pc_w;
            commit_instr_reg    <= inst_w;
            commit_halt_reg     <= halt_w;
            commit_reg_we_reg   <= rf_we_w;
            commit_reg_wa_reg   <= rf_wa_w;
            commit_reg_wd_reg   <= rf_wd_w;
            commit_dmem_we_reg  <= 1'b0;
            commit_dmem_wa_reg  <= 32'b0;
            commit_dmem_wd_reg  <= 32'b0;
        end
    end

    assign commit           = commit_reg;
    assign commit_pc        = commit_pc_reg;
    assign commit_instr     = commit_instr_reg;
    assign commit_halt      = commit_halt_reg;
    assign commit_reg_we    = commit_reg_we_reg;
    assign commit_reg_wa    = commit_reg_wa_reg;
    assign commit_reg_wd    = commit_reg_wd_reg;
    assign commit_dmem_we   = commit_dmem_we_reg;
    assign commit_dmem_wa   = commit_dmem_wa_reg;
    assign commit_dmem_wd   = commit_dmem_wd_reg;

endmodule
