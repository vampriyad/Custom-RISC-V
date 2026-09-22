`timescale 1ns/1ps
`include "defs.svh"
module tb_alu;
    logic [31:0] a, b, y;
    logic [3:0] op;
    logic eq, lt, ltu;
    alu dut (.a, .b, .op, .y, .eq, .lt, .ltu);
    int errors = 0;

    function automatic [31:0] ref_alu(input logic [31:0] ra, rb, input logic [3:0] rop);
        logic [31:0] r, sra_lo, sra_hi;
        logic [63:0] prod;
        if (rop == `ALU_SRA && rb[4:0] != 0) begin
            sra_lo = ra >> rb[4:0];
            sra_hi = {32{ra[31]}} << (32 - rb[4:0]);
            sra_lo = sra_lo | sra_hi;
        end else sra_lo = ra >> rb[4:0];
        prod = ra * rb;
        case (rop)
            `ALU_ADD: r = ra + rb;
            `ALU_SUB: r = ra - rb;
            `ALU_SLL: r = ra << rb[4:0];
            `ALU_SLT: r = ($signed(ra) < $signed(rb)) ? 1 : 0;
            `ALU_SLTU: r = (ra < rb) ? 1 : 0;
            `ALU_XOR: r = ra ^ rb;
            `ALU_SRL: r = ra >> rb[4:0];
            `ALU_SRA: r = sra_lo;
            `ALU_OR: r = ra | rb;
            `ALU_AND: r = ra & rb;
            `ALU_MUL: r = prod[31:0];
            default: r = 0;
        endcase
        return r;
    endfunction

    task automatic run(input logic [31:0] ta, tb, input logic [3:0] top);
        a = ta; b = tb; op = top; #1;
        if (y !== ref_alu(ta, tb, top)) begin
            $display("FAIL op=%0d a=%h b=%h y=%h exp=%h", top, ta, tb, y, ref_alu(ta, tb, top));
            errors++;
        end
    endtask

    initial begin
        run(5, 7, `ALU_ADD);
        run(32'hFFFFFFFF, 1, `ALU_ADD);
        run(10, 3, `ALU_SUB);
        run(0, 1, `ALU_SUB);
        run(32'h80000000, 1, `ALU_AND);
        run(32'hF0F0F0F0, 32'h0F0F0F0F, `ALU_OR);
        run(32'hAAAAAAAA, 32'h55555555, `ALU_XOR);
        run(1, 31, `ALU_SLL);
        run(32'h80000000, 31, `ALU_SRL);
        run(32'h80000000, 31, `ALU_SRA);
        run(32'hFFFFFFFF, 1, `ALU_SLT);
        run(32'hFFFFFFFF, 1, `ALU_SLTU);
        run(7, 6, `ALU_MUL);
        for (int i = 0; i < 5000; i++) begin
            logic [31:0] ra, rb;
            logic [3:0] rop;
            ra = $random; rb = $random; rop = $random % 11;
            run(ra, rb, rop);
        end
        if (errors == 0) $display("=== tb_alu PASSED ===");
        else $display("=== tb_alu FAILED === %0d errors", errors);
        $finish;
    end
endmodule
