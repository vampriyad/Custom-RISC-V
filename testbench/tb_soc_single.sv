`timescale 1ns/1ps
module tb_soc_single;
    localparam DIV = 4;
    logic clk = 0, rst_n = 0;
    logic uart_rx = 1'b1;
    wire uart_tx;
    wire exit_valid;
    wire [31:0] exit_code;
    wire [31:0] dbg_pc, dbg_instr;

    soc_single #(.WORDS(1024), .UART_DIV(DIV)) dut (
        .clk, .rst_n, .uart_rx, .uart_tx,
        .exit_valid, .exit_code, .dbg_pc, .dbg_instr
    );

    always #5 clk = ~clk;

    longint cycles = 0;
    longint instrs = 0;
    always_ff @(posedge clk) begin
        cycles <= cycles + 1;
        if (dut.u_core.dbg_instr_retiring) instrs <= instrs + 1;
    end

    initial begin : uart_mon
        byte b;
        forever begin
            @(negedge uart_tx);
            #(10 * DIV * 1.5);
            for (int i = 0; i < 8; i++) begin
                b[i] = uart_tx;
                #(10 * DIV);
            end
            $write("%c", b);
            $fflush(32'h8000_0001);
        end
    end

    initial begin
        if ($test$plusargs("DUMP")) begin
            $dumpfile("build/wave.vcd");
            $dumpvars(0, tb_soc_single);
        end
    end

    int timeout = 200000;
    initial begin
        void'($value$plusargs("TIMEOUT=%d", timeout));
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        while (!exit_valid && cycles < timeout) @(posedge clk);
        $display("");
        if (!exit_valid) begin
            $display("[tb] TIMEOUT after %0d cycles instrs=%0d pc=%h", cycles, instrs, dbg_pc);
            $display("=== tb_soc_single FAILED ===");
        end else begin
            $display("[tb] EXIT code=%0d cycles=%0d instrs=%0d", exit_code, cycles, instrs);
            if (exit_code == 1) $display("=== tb_soc_single PASSED ===");
            else $display("=== tb_soc_single FAILED === code=%0d", exit_code);
        end
        $finish;
    end
endmodule
