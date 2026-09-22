`timescale 1ns/1ps
module tb_regfile;
    logic clk = 0;
    logic we;
    logic [4:0] waddr, raddr1, raddr2;
    logic [31:0] wdata, rdata1, rdata2;

    regfile dut (.clk, .we, .waddr, .wdata, .raddr1, .raddr2, .rdata1, .rdata2);

    always #5 clk = ~clk;

    logic [31:0] shadow [0:31];
    int errors = 0;

    task automatic tick_write(input logic twe, input logic [4:0] twa,
                              input logic [31:0] twd);
        begin
            we = twe; waddr = twa; wdata = twd;
            @(posedge clk);
            #1;
            if (twe && (twa != 0))
                shadow[twa] = twd;
            we = 0;
        end
    endtask

    task automatic check_read(input logic [4:0] ta, input logic [4:0] tb);
        begin
            raddr1 = ta; raddr2 = tb;
            #1;
            if (rdata1 !== shadow[ta]) begin
                $display("FAIL: read x%0d = %h expected %h", ta, rdata1, shadow[ta]);
                errors++;
            end
            if (rdata2 !== shadow[tb]) begin
                $display("FAIL: read x%0d = %h expected %h", tb, rdata2, shadow[tb]);
                errors++;
            end
        end
    endtask

    initial begin
        for (int i = 0; i < 32; i++) shadow[i] = 32'h0;

        check_read(0, 0);

        tick_write(1, 5'd1, 32'hAAAA_0001);
        tick_write(1, 5'd2, 32'hAAAA_0002);
        check_read(5'd1, 5'd2);

        tick_write(1, 5'd0, 32'hDEAD_BEEF);
        check_read(5'd0, 5'd0);
        check_read(5'd1, 5'd0);

        we = 1; waddr = 5'd3; wdata = 32'hCAFE_F00D; raddr1 = 5'd3; raddr2 = 0;
        #1;
        if (rdata1 !== 32'hCAFE_F00D) begin
            $display("FAIL: write-first bypass got %h", rdata1);
            errors++;
        end
        @(posedge clk); #1;
        shadow[3] = 32'hCAFE_F00D;
        we = 0;

        for (int i = 0; i < 2000; i++) begin
            logic [4:0] wa, ra1, ra2;
            logic [31:0] wd;
            wa = {$random} % 32;
            ra1 = {$random} % 32;
            ra2 = {$random} % 32;
            wd = {$random};
            check_read(ra1, ra2);
            tick_write($random & 1, wa, wd);
            check_read(ra1, ra2);
        end

        if (errors == 0) $display("=== tb_regfile PASSED ==="); else $display("=== tb_regfile FAILED === %0d errors", errors);
        $finish;
    end
endmodule
