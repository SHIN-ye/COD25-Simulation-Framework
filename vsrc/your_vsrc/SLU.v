`timescale 1ns / 1ps

module SLU(
    input  [31 : 0] addr,
    input  [ 3 : 0] dmem_access,
    input  [31 : 0] rd_in,
    input  [31 : 0] wd_in,
    output reg [31 : 0] rd_out,
    output reg [31 : 0] wd_out
);

    // 访存类型定义
    `define DMEM_NO_ACCESS 4'd0
    `define DMEM_LB        4'd1
    `define DMEM_LH        4'd2
    `define DMEM_LW        4'd3
    `define DMEM_LBU       4'd4
    `define DMEM_LHU       4'd5
    `define DMEM_SB        4'd6
    `define DMEM_SH        4'd7
    `define DMEM_SW        4'd8

    wire [1:0] offset = addr[1:0];

    // 处理读出数据截取与符号扩展
    always @(*) begin
        case(dmem_access)
            `DMEM_LB: begin
                case(offset)
                    2'b00: rd_out = {{24{rd_in[ 7]}}, rd_in[ 7: 0]};
                    2'b01: rd_out = {{24{rd_in[15]}}, rd_in[15: 8]};
                    2'b10: rd_out = {{24{rd_in[23]}}, rd_in[23:16]};
                    2'b11: rd_out = {{24{rd_in[31]}}, rd_in[31:24]};
                endcase
            end
            `DMEM_LBU: begin
                case(offset)
                    2'b00: rd_out = {24'b0, rd_in[ 7: 0]};
                    2'b01: rd_out = {24'b0, rd_in[15: 8]};
                    2'b10: rd_out = {24'b0, rd_in[23:16]};
                    2'b11: rd_out = {24'b0, rd_in[31:24]};
                endcase
            end
            `DMEM_LH: begin
                if (offset[1] == 1'b0)
                    rd_out = {{16{rd_in[15]}}, rd_in[15: 0]};
                else
                    rd_out = {{16{rd_in[31]}}, rd_in[31:16]};
            end
            `DMEM_LHU: begin
                if (offset[1] == 1'b0)
                    rd_out = {16'b0, rd_in[15: 0]};
                else
                    rd_out = {16'b0, rd_in[31:16]};
            end
            `DMEM_LW: rd_out = rd_in;
            default:  rd_out = rd_in;
        endcase
    end

    // 处理写入数据掩码拼装
    always @(*) begin
        case(dmem_access)
            `DMEM_SB: begin
                case(offset)
                    2'b00: wd_out = {rd_in[31: 8], wd_in[7:0]};
                    2'b01: wd_out = {rd_in[31:16], wd_in[7:0], rd_in[ 7:0]};
                    2'b10: wd_out = {rd_in[31:24], wd_in[7:0], rd_in[15:0]};
                    2'b11: wd_out = {wd_in[7:0], rd_in[23:0]};
                endcase
            end
            `DMEM_SH: begin
                if (offset[1] == 1'b0)
                    wd_out = {rd_in[31:16], wd_in[15:0]};
                else
                    wd_out = {wd_in[15:0],  rd_in[15:0]};
            end
            `DMEM_SW: wd_out = wd_in;
            default:  wd_out = wd_in;
        endcase
    end

endmodule
