`timescale 1ns / 1ps

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

module decoder (
    input  [31:0] inst,         
    output [ 4:0] alu_op,       
    output [31:0] imm,          
    output [ 4:0] rf_ra0,       
    output [ 4:0] rf_ra1,       
    output [ 4:0] rf_wa,        
    output        rf_we,        
    output        alu_src0_sel, 
    output        alu_src1_sel,    output        halt,
    output [ 3:0] br_type,      // 送给BRANCH模块
    output [ 3:0] dmem_access,  // 送给SLU模块 
    output        dmem_we,      // 写内存使能
    output [ 1:0] rf_wd_sel     // 选什么写回寄存器 00: ALU  01: PC+4(JAL)  10: MEM(Load指令)
);

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    assign rf_ra0 = inst[19:15]; // rs1
    assign rf_ra1 = inst[24:20]; // rs2
    assign rf_wa  = inst[11:7]; // rd

    wire is_R_type = (opcode == 7'b0110011);
    wire is_I_type = (opcode == 7'b0010011);
    wire is_LUI    = (opcode == 7'b0110111);
    wire is_AUIPC  = (opcode == 7'b0010111);
    wire is_Load   = (opcode == 7'b0000011);
    wire is_Store  = (opcode == 7'b0100011);
    wire is_Branch = (opcode == 7'b1100011);
    wire is_JAL    = (opcode == 7'b1101111);
    wire is_JALR   = (opcode == 7'b1100111);
    wire is_ebreak = (inst == 32'h00100073);

    assign halt = is_ebreak;

    wire [31:0] imm_I = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] imm_S = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    wire [31:0] imm_B = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [31:0] imm_U = {inst[31:12], 12'b0};
    wire [31:0] imm_J = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};

    assign imm = is_Store  ? imm_S : 
                 is_Branch ? imm_B : 
                 is_JAL    ? imm_J : 
                 (is_LUI | is_AUIPC) ? imm_U : imm_I;

    assign rf_we = is_R_type | is_I_type | is_Load | is_JAL | is_JALR | is_LUI | is_AUIPC;

    assign dmem_we = is_Store;

    assign rf_wd_sel = (is_JAL | is_JALR) ? 2'b01 : 
                       is_Load ? 2'b10 : 2'b00;

    assign alu_src0_sel = (is_AUIPC | is_Branch | is_JAL) ? 1'b1 : 1'b0;

    assign alu_src1_sel = ~(is_R_type);

    reg [4:0] alu_op_reg;
    always @(*) begin
        if (is_LUI) begin
            alu_op_reg = `SRC1; 
        end
        else if (is_AUIPC) begin
            alu_op_reg = `ADD; 
        end
        else if (is_R_type || is_I_type) begin
            case(funct3)
                3'b000: begin
                    if (is_R_type && funct7[5]) 
                        alu_op_reg = `SUB;
                    else
                        alu_op_reg = `ADD;
                end
                3'b001: alu_op_reg = `SLL;
                3'b010: alu_op_reg = `SLT;
                3'b011: alu_op_reg = `SLTU;
                3'b100: alu_op_reg = `XOR;
                3'b101: begin
                    if (funct7[5])
                        alu_op_reg = `SRA;
                    else
                        alu_op_reg = `SRL;
                end
                3'b110: alu_op_reg = `OR;
                3'b111: alu_op_reg = `AND;
                default: alu_op_reg = `ADD;
            endcase
        end
        else begin
            alu_op_reg = `ADD;
        end
    end

    assign alu_op = alu_op_reg;

    reg [3:0] br_type_reg;
    always @(*) begin
        if (is_Branch) begin
            case (funct3)
                3'b000: br_type_reg = 4'd1; // BEQ
                3'b001: br_type_reg = 4'd2; // BNE
                3'b100: br_type_reg = 4'd3; // BLT
                3'b101: br_type_reg = 4'd4; // BGE
                3'b110: br_type_reg = 4'd5; // BLTU
                3'b111: br_type_reg = 4'd6; // BGEU
                default: br_type_reg = 4'd0;
            endcase
        end else if (is_JAL) begin
            br_type_reg = 4'd7;
        end else if (is_JALR) begin
            br_type_reg = 4'd8;
        end else begin
            br_type_reg = 4'd0;
        end
    end
    assign br_type = br_type_reg;

    reg [3:0] dmem_access_reg;
    always @(*) begin
        if (is_Load || is_Store) begin
            case (funct3)
                3'b000: dmem_access_reg = is_Store ? 4'd6 : 4'd1; // SB/LB
                3'b001: dmem_access_reg = is_Store ? 4'd7 : 4'd2; // SH/LH
                3'b010: dmem_access_reg = is_Store ? 4'd8 : 4'd3; // SW/LW
                3'b100: dmem_access_reg = 4'd4; // LBU
                3'b101: dmem_access_reg = 4'd5; // LHU
                default: dmem_access_reg = 4'd0;
            endcase
        end else begin
            dmem_access_reg = 4'd0;
        end
    end
    assign dmem_access = dmem_access_reg;
    
endmodule
