`timescale 1ns / 1ps

module PC (
    input             clk,
    input             rst,
    input             en,
    input             stall,
    input      [31:0] npc,
    output reg [31:0] pc
);

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h00400000;
        end
        else if (en && !stall) begin
            pc <= npc;
        end
    end

endmodule
    