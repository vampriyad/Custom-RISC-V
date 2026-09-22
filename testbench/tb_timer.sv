`timescale 1ns/1ps
module tb_timer;
    logic clk = 0, rst_n = 0;
    logic req, we;
    logic [3:0] addr;
    logic [31:0] wdata, rdata;
    logic irq;

    timer dut (.clk, .rst_n, .req, .we, .addr, .wdata, .rdata, .irq);

    always #5 clk = ~clk;

    int errors = 0;

    task automatic wr(input logic [3:0] a, input logic [31:0] d);
        begin
            @(negedge clk);
            req = 1; we = 1; addr = a; wdata = d;
            @(negedge clk);
            req = 0; we = 0;
        end
    endtask

    task automatic rd_reg(input logic [3:0] a, output logic [31:0] d);
        begin
            @(negedge clk);
            req = 1; we = 0; addr = a;
            #1;
            d = rdata;
            @(negedge clk);
            req = 0;
        end
    endtask

    logic [31:0] v, v2;

    initial begin
        #20 rst_n = 1;

        rd_reg(4'd0, v);
        repeat (5) @(negedge clk);
        rd_reg(4'd0, v2);
        if (v2 - v < 4) begin
            $display("FAIL: counter did not advance (%0d -> %0d)", v, v2);
            errors++;
        end

        wr(4'd0, 32'd100);
        rd_reg(4'd0, v);
        if (v < 32'd100 || v > 32'd103) begin
            $display("FAIL: counter load, read back %0d", v);
            errors++;
        end

        rd_reg(4'd0, v);
        wr(4'd1, v + 32'd5);
        wr(4'd2, 32'd1);
        if (irq !== 1'b0) begin $display("FAIL: irq early"); errors++; end

        repeat (12) @(negedge clk);
        if (irq !== 1'b1) begin $display("FAIL: no irq after match"); errors++; end

        rd_reg(4'd2, v);
        if (v[1:0] !== 2'b11) begin $display("FAIL: ctrl %h want 3", v); errors++; end

        wr(4'd2, 32'd3);
        if (irq !== 1'b0) begin $display("FAIL: irq stuck after W1C"); errors++; end

        wr(4'd2, 32'd0);
        rd_reg(4'd0, v);
        wr(4'd1, v + 32'd4);
        repeat (10) @(negedge clk);
        if (irq !== 1'b0) begin $display("FAIL: irq without enable"); errors++; end
        rd_reg(4'd2, v);
        if (v[1] !== 1'b1) begin $display("FAIL: pending not set"); errors++; end

        if (errors == 0) $display("=== tb_timer PASSED ==="); else $display("=== tb_timer FAILED === %0d errors", errors);
        $finish;
    end
endmodule
