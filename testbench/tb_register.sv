`timescale 1ns/1ps
module tb_register;
    logic clk = 0, rst_n = 0, en;
    logic [31:0] d, q;

    register #(.WIDTH(32)) dut (.clk, .rst_n, .en, .d, .q);

    always #5 clk = ~clk;

    int errors = 0;

    initial begin
        rst_n = 0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        if (q !== 32'h0) begin $display("FAIL: reset value %h", q); errors++; end

        en = 0; d = 32'hDEAD_BEEF;
        @(negedge clk);
        if (q !== 32'h0) begin $display("FAIL: wrote while en=0"); errors++; end

        en = 1; d = 32'h1234_5678;
        @(negedge clk);
        if (q !== 32'h1234_5678) begin $display("FAIL: load %h", q); errors++; end

        rst_n = 0; #1;
        if (q !== 32'h0) begin $display("FAIL: async reset %h", q); errors++; end

        if (errors == 0) $display("=== tb_register PASSED ==="); else $display("=== tb_register FAILED === %0d errors", errors);
        $finish;
    end
endmodule
