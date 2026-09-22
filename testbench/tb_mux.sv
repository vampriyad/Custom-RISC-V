`timescale 1ns/1ps
module tb_mux;
    logic [31:0] a32, b32, y32;
    logic [7:0]  a8, b8, y8;
    logic sel;

    mux #(.WIDTH(32)) dut32 (.a(a32), .b(b32), .sel, .y(y32));
    mux #(.WIDTH(8))  dut8  (.a(a8),  .b(b8),  .sel, .y(y8));

    int errors = 0;

    task check32(input logic s, input logic [31:0] va, input logic [31:0] vb);
        begin
            sel = s; a32 = va; b32 = vb;
            #1;
            if (y32 !== (s ? vb : va)) begin
                $display("FAIL32: sel=%b a=%h b=%h -> %h", s, va, vb, y32);
                errors++;
            end
        end
    endtask

    task check8(input logic s, input logic [7:0] va, input logic [7:0] vb);
        begin
            sel = s; a8 = va; b8 = vb;
            #1;
            if (y8 !== (s ? vb : va)) begin
                $display("FAIL8: sel=%b a=%h b=%h -> %h", s, va, vb, y8);
                errors++;
            end
        end
    endtask

    initial begin
        check32(0, 32'hAAAA_AAAA, 32'h5555_5555);
        check32(1, 32'hAAAA_AAAA, 32'h5555_5555);
        check32(0, 32'h0000_0000, 32'hFFFF_FFFF);
        check32(1, 32'h0000_0000, 32'hFFFF_FFFF);
        check8(0, 8'h00, 8'hFF);
        check8(1, 8'h00, 8'hFF);
        for (int i = 0; i < 100; i++) begin
            logic [31:0] ra, rb; logic rs;
            ra = {$random}; rb = {$random}; rs = $random;
            check32(rs, ra, rb);
            check8(rs, ra[7:0], rb[7:0]);
        end
        if (errors == 0) $display("=== tb_mux PASSED ==="); else $display("=== tb_mux FAILED === %0d errors", errors);
        $finish;
    end
endmodule
