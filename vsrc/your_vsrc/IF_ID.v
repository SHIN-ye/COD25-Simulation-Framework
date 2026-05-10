`timescale 1ns / 1ps

module IF_ID (
    input         clk, rst, en, stall, flush,
    input  [31:0] pc_f, inst_f,
    output reg [31:0] pc_d, inst_d,
    output reg        commit_d
);
    always @(posedge clk) begin
        if (rst) begin
            pc_d     <= 32'b0;
            inst_d   <= 32'h00000013;  // NOP
            commit_d <= 1'b0;
        end else if (flush) begin
            pc_d     <= 32'b0;
            inst_d   <= 32'h00000013;
            commit_d <= 1'b0;
        end else if (en && !stall) begin
            pc_d     <= pc_f;
            inst_d   <= inst_f;
            commit_d <= 1'b1;
        end
    end
endmodule
