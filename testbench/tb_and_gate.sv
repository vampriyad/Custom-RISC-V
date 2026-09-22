`timescale 1ns/1ps
module tb_and_gate;
    logic a, b;
    logic y;

    and_gate dut (.a, .b, .y);

    int errors = 0;

    task check(input logic ea, input logic eb);
        begin
            a = ea; b = eb;
            #1;
            if (y !== (ea & eb)) begin
                $display("FAIL: a=%b b=%b -> y=%b expected %b", a, b, y, ea & eb);
                errors++;
            end
        end
    endtask

    initial begin
        check(0, 0);
        check(0, 1);
        check(1, 0);
        check(1, 1);
        if (errors == 0) $display("=== tb_and_gate PASSED ==="); else $display("=== tb_and_gate FAILED === %0d errors", errors);
        $finish;
    end
endmodule
