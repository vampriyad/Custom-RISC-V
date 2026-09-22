`timescale 1ns/1ps
`include "defs.svh"

module tb_imm_gen;
    logic [31:0] instr, imm;
    logic [2:0]  imm_type;

    imm_gen dut (.instr, .imm_type, .imm);

    int errors = 0;

    task automatic check(input logic [2:0] t, input logic [31:0] ins,
                         input logic [31:0] expected);
        begin
            imm_type = t; instr = ins;
            #1;
            if (imm !== expected) begin
                $display("FAIL: type %0d instr %h -> %h expected %h", t, ins, imm, expected);
                errors++;
            end
        end
    endtask

    initial begin
        check(`IMM_I, 32'h1231_0093, 32'h0000_0123);
        check(`IMM_I, 32'hFFF1_0093, 32'hFFFF_FFFF);
        check(`IMM_S, 32'h0032_2423, 32'h0000_0008);
        check(`IMM_S, 32'hFE32_2823, 32'hFFFF_FFF0);
        check(`IMM_B, 32'h0020_8863, 32'h0000_0010);
        check(`IMM_B, 32'hFE20_98E3, 32'hFFFF_FFF0);
        check(`IMM_U, 32'hABCDE_2B7, 32'hABCD_E000);
        check(`IMM_J, 32'h0240_00EF, 32'h0000_0024);
        check(`IMM_J, 32'hFFDF_F0EF, 32'hFFFF_FFFC);

        if (errors == 0) $display("=== tb_imm_gen PASSED ==="); else $display("=== tb_imm_gen FAILED === %0d errors", errors);
        $finish;
    end
endmodule
