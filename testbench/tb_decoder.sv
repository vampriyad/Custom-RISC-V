`timescale 1ns/1ps
`include "defs.svh"

module tb_decoder;
    logic [31:0] instr;
    logic        reg_we, mem_we, alu_b_imm, jalr, is_mret, is_cus, illegal;
    logic [1:0]  wb_sel, alu_a_sel;
    logic [3:0]  alu_op;
    logic [2:0]  br_type, imm_type;

    decoder dut (.*);

    int errors = 0;

    task automatic expect_sig(input logic [31:0] ins,
                              input logic e_reg_we, input logic [1:0] e_wb_sel,
                              input logic e_mem_we, input logic [1:0] e_alu_a_sel,
                              input logic e_alu_b_imm, input logic [3:0] e_alu_op,
                              input logic [2:0] e_br_type, input logic e_jalr,
                              input logic [2:0] e_imm_type,
                              input logic e_mret, input logic e_cus, input logic e_ill);
        begin
            instr = ins;
            #1;
            if (reg_we !== e_reg_we || wb_sel !== e_wb_sel || mem_we !== e_mem_we ||
                alu_a_sel !== e_alu_a_sel || alu_b_imm !== e_alu_b_imm ||
                alu_op !== e_alu_op || br_type !== e_br_type || jalr !== e_jalr ||
                imm_type !== e_imm_type || is_mret !== e_mret ||
                is_cus !== e_cus || illegal !== e_ill) begin
                $display("FAIL instr %h", ins);
                $display("   got  we=%b wb=%b mw=%b aa=%b ab=%b op=%0d br=%0d jr=%b im=%0d mret=%b cus=%b ill=%b",
                         reg_we, wb_sel, mem_we, alu_a_sel, alu_b_imm, alu_op,
                         br_type, jalr, imm_type, is_mret, is_cus, illegal);
                $display("   want we=%b wb=%b mw=%b aa=%b ab=%b op=%0d br=%0d jr=%b im=%0d mret=%b cus=%b ill=%b",
                         e_reg_we, e_wb_sel, e_mem_we, e_alu_a_sel, e_alu_b_imm, e_alu_op,
                         e_br_type, e_jalr, e_imm_type, e_mret, e_cus, e_ill);
                errors++;
            end
        end
    endtask

    initial begin
        expect_sig(32'h0073_02B3,      1, `WB_ALU, 0, `AA_RS1, 0, `ALU_ADD,  `BR_NONE, 0, `IMM_I, 0, 0, 0);
        expect_sig(32'h4073_02B3,      1, `WB_ALU, 0, `AA_RS1, 0, `ALU_SUB,  `BR_NONE, 0, `IMM_I, 0, 0, 0);
        expect_sig(32'h0273_02B3,      1, `WB_ALU, 0, `AA_RS1, 0, `ALU_MUL,  `BR_NONE, 0, `IMM_I, 0, 0, 0);
        expect_sig(32'h00A1_0093,      1, `WB_ALU, 0, `AA_RS1, 1, `ALU_ADD,  `BR_NONE, 0, `IMM_I, 0, 0, 0);
        expect_sig(32'h4031_5093,      1, `WB_ALU, 0, `AA_RS1, 1, `ALU_SRA,  `BR_NONE, 0, `IMM_I, 0, 0, 0);
        expect_sig(32'h0082_2183,      1, `WB_MEM, 0, `AA_RS1, 1, `ALU_ADD,  `BR_NONE, 0, `IMM_I, 0, 0, 0);
        expect_sig(32'h0032_2423,      0, `WB_ALU, 1, `AA_RS1, 1, `ALU_ADD,  `BR_NONE, 0, `IMM_S, 0, 0, 0);
        expect_sig(32'h0020_8063,      0, `WB_ALU, 0, `AA_RS1, 0, `ALU_ADD,  `BR_EQ,   0, `IMM_B, 0, 0, 0);
        expect_sig(32'h0020_E063,      0, `WB_ALU, 0, `AA_RS1, 0, `ALU_ADD,  `BR_LTU,  0, `IMM_B, 0, 0, 0);
        expect_sig(32'h1234_52B7,      1, `WB_ALU, 0, `AA_ZERO, 1, `ALU_ADD,  `BR_NONE, 0, `IMM_U, 0, 0, 0);
        expect_sig(32'h0000_1297,      1, `WB_ALU, 0, `AA_PC,   1, `ALU_ADD,  `BR_NONE, 0, `IMM_U, 0, 0, 0);
        expect_sig(32'h0000_00EF,      1, `WB_PC4, 0, `AA_RS1, 0, `ALU_ADD,  `BR_JUMP, 0, `IMM_J, 0, 0, 0);
        expect_sig(32'h0001_00E7,      1, `WB_PC4, 0, `AA_RS1, 0, `ALU_ADD,  `BR_JUMP, 1, `IMM_I, 0, 0, 0);
        expect_sig(32'h3020_0073,      0, `WB_ALU, 0, `AA_RS1, 0, `ALU_ADD,  `BR_NONE, 0, `IMM_I, 1, 0, 0);
        expect_sig(32'h0000_028B,      1, `WB_ALU, 0, `AA_RS1, 0, `ALU_ADD,  `BR_NONE, 0, `IMM_I, 0, 1, 0);
        expect_sig(32'h0000_0073,      0, `WB_ALU, 0, `AA_RS1, 0, `ALU_ADD,  `BR_NONE, 0, `IMM_I, 0, 0, 1);

        if (errors == 0) $display("=== tb_decoder PASSED ==="); else $display("=== tb_decoder FAILED === %0d errors", errors);
        $finish;
    end
endmodule
