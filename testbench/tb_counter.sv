`timescale 1ns/1ps
module tb_counter;
    logic clk = 0, rst_n = 0, en;
    logic [3:0] q;
    logic tick;

    counter #(.WIDTH(4)) dut (.clk, .rst_n, .en, .q, .tick);

    always #5 clk = ~clk;

    int errors = 0;

    initial begin
        rst_n = 0;
        en = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);
        if (q !== 4'h0) begin $display("FAIL: counts while disabled"); errors++; end

        en = 1;
        for (int i = 1; i <= 14; i++) begin
            @(negedge clk);
            if (q !== i[3:0]) begin $display("FAIL: count %0d got %0d", i, q); errors++; end
        end
        if (tick !== 1'b0) begin $display("FAIL: tick early"); errors++; end
        @(negedge clk);
        if (q !== 4'hF) begin $display("FAIL: expected 15"); errors++; end
        if (tick !== 1'b1) begin $display("FAIL: no tick at max"); errors++; end
        @(negedge clk);
        if (q !== 4'h0) begin $display("FAIL: no wrap"); errors++; end

        if (errors == 0) $display("=== tb_counter PASSED ==="); else $display("=== tb_counter FAILED === %0d errors", errors);
        $finish;
    end
endmodule
