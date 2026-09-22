`timescale 1ns/1ps
module tb_uart;
    localparam DIV = 4;

    logic clk = 0, rst_n = 0;
    logic req, we;
    logic [3:0] addr;
    logic [31:0] wdata, rdata;
    wire  tx;
    logic rx;
    assign rx = tx;

    uart #(.DIV(DIV)) dut (.clk, .rst_n, .req, .we, .addr, .wdata, .rdata, .rx, .tx);

    always #5 clk = ~clk;

    int errors = 0;
    logic [31:0] v;
    logic [7:0] got;
    logic ok;

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

    task automatic wait_rx_byte(output logic [7:0] b, output logic ok_o);
        logic [31:0] s;
        int guard;
        begin
            ok_o = 0; guard = 0;
            while (!ok_o && guard < 200) begin
                rd_reg(4'd1, s);
                if (s[1]) begin
                    rd_reg(4'd2, s);
                    b = s[7:0];
                    ok_o = 1;
                end
                guard++;
            end
        end
    endtask

    task automatic send_and_check(input logic [7:0] byte_v);
        begin
            wr(4'd0, {24'h0, byte_v});
            rd_reg(4'd1, v);
            if (v[0] !== 1'b1) begin
                $display("FAIL: tx not busy after start of %h", byte_v);
                errors++;
            end
            wait_rx_byte(got, ok);
            if (!ok) begin
                $display("FAIL: timeout waiting for %h", byte_v);
                errors++;
            end else if (got !== byte_v) begin
                $display("FAIL: got %h expected %h", got, byte_v);
                errors++;
            end
        end
    endtask

    initial begin
        #20 rst_n = 1;
        @(negedge clk);

        rd_reg(4'd1, v);
        if (v[1:0] !== 2'b00) begin $display("FAIL: initial status %h", v); errors++; end

        send_and_check(8'h55);
        send_and_check(8'hA3);
        send_and_check(8'h00);
        send_and_check(8'hFF);

        rd_reg(4'd1, v);
        if (v[1] !== 1'b0) begin
            $display("FAIL: rx avail not cleared by RXDATA read");
            errors++;
        end

        if (errors == 0) $display("=== tb_uart PASSED ==="); else $display("=== tb_uart FAILED === %0d errors", errors);
        $finish;
    end
endmodule
