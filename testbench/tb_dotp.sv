`timescale 1ns/1ps
module tb_dotp;
    logic clk = 0, rst_n = 0;
    logic req, we, cus_req;
    logic [5:0] addr;
    logic [31:0] wdata, rdata, cus_result;

    dotp dut (.clk, .rst_n, .req, .we, .addr, .wdata, .rdata,
              .cus_req, .cus_result);

    always #5 clk = ~clk;

    int errors = 0;

    task automatic wr(input logic [5:0] a, input logic [31:0] d);
        begin
            @(negedge clk);
            req = 1; we = 1; addr = a; wdata = d;
            @(negedge clk);
            req = 0; we = 0;
        end
    endtask

    function automatic [31:0] ref_dot(input logic [31:0] a0, a1, a2, a3,
                                      input logic [31:0] b0, b1, b2, b3);
        logic signed [63:0] acc;
        acc = 0;
        acc += $signed(a0) * $signed(b0);
        acc += $signed(a1) * $signed(b1);
        acc += $signed(a2) * $signed(b2);
        acc += $signed(a3) * $signed(b3);
        return acc[31:0];
    endfunction

    logic [31:0] a0, a1, a2, a3, b0, b1, b2, b3, expected;

    task automatic load_vectors;
        begin
            wr(6'd0, a0); wr(6'd1, a1); wr(6'd2, a2); wr(6'd3, a3);
            wr(6'd4, b0); wr(6'd5, b1); wr(6'd6, b2); wr(6'd7, b3);
        end
    endtask

    logic [31:0] v;

    initial begin
        rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        a0=1; a1=2; a2=3; a3=4; b0=5; b1=6; b2=7; b3=8;
        load_vectors;
        @(negedge clk);
        cus_req = 1; #1;
        if (cus_result !== 32'd70) begin
            $display("FAIL: directed dot %0d expected 70", cus_result);
            errors++;
        end
        @(negedge clk);
        cus_req = 0;

        wr(6'd9, 32'h1);
        @(negedge clk);
        req = 1; we = 0; addr = 6'd8; #1;
        if (rdata !== 32'd70) begin
            $display("FAIL: RESULT latch %0d expected 70", rdata);
            errors++;
        end
        @(negedge clk);
        req = 0;

        begin
            logic [31:0] exp2;
            a0=1; a1=1; a2=1; a3=1; b0=1; b1=1; b2=1; b3=1;
            load_vectors;
            a0 = 10;
            expected = ref_dot(a0, a1, a2, a3, b0, b1, b2, b3);
            @(negedge clk);
            req = 1; we = 1; addr = 6'd0; wdata = a0; cus_req = 1;
            #1;
            if (cus_result !== expected) begin
                $display("FAIL: bypass got %h expected %h", cus_result, expected);
                errors++;
            end
            @(negedge clk);
            req = 0; we = 0; cus_req = 0;
        end

        for (int i = 0; i < 500; i++) begin
            a0 = {$random}; a1 = {$random}; a2 = {$random}; a3 = {$random};
            b0 = {$random}; b1 = {$random}; b2 = {$random}; b3 = {$random};
            expected = ref_dot(a0, a1, a2, a3, b0, b1, b2, b3);
            load_vectors;
            @(negedge clk);
            cus_req = 1; #1;
            if (cus_result !== expected) begin
                $display("FAIL: vector %0d got %h expected %h", i, cus_result, expected);
                errors++;
            end
            @(negedge clk);
            cus_req = 0;
            wr(6'd9, 32'h1);
            @(negedge clk);
            req = 1; we = 0; addr = 6'd8; #1;
            if (rdata !== expected) begin
                $display("FAIL: RESULT path vector %0d got %h expected %h", i, rdata, expected);
                errors++;
            end
            @(negedge clk);
            req = 0;
        end

        if (errors == 0) $display("=== tb_dotp PASSED ==="); else $display("=== tb_dotp FAILED === %0d errors", errors);
        $finish;
    end
endmodule
