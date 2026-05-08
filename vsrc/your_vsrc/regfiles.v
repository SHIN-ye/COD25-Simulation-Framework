`timescale 1ns / 1ps

module regfiles (
    input                   clk,

    input          [ 4 : 0] rf_ra0,
    input          [ 4 : 0] rf_ra1,   
    input          [ 4 : 0] rf_wa,
    input                   rf_we,
    input          [31 : 0] rf_wd,

    output         [31 : 0] rf_rd0,
    output         [31 : 0] rf_rd1,
    
    // debug 
    input          [ 4 : 0] debug_reg_ra,
    output         [31 : 0] debug_reg_rd
);

    reg [31 : 0] reg_file [0 : 31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            reg_file[i] = 32'b0;
    end

    // 写优先：当 rf_we 有效且读地址 == 写地址时，直接输出待写入数据
    assign rf_rd0 = (rf_ra0 == 5'b0) ? 32'b0 :
                    (rf_we && (rf_ra0 == rf_wa)) ? rf_wd :
                    reg_file[rf_ra0];
    assign rf_rd1 = (rf_ra1 == 5'b0) ? 32'b0 :
                    (rf_we && (rf_ra1 == rf_wa)) ? rf_wd :
                    reg_file[rf_ra1];

    // debug
    assign debug_reg_rd = (debug_reg_ra == 5'b0) ? 32'b0 :
                          (rf_we && (debug_reg_ra == rf_wa)) ? rf_wd :
                          reg_file[debug_reg_ra];

    always @(posedge clk) begin
        if (rf_we && (rf_wa != 5'b0)) begin
            reg_file[rf_wa] <= rf_wd;
        end
    end
    
endmodule
