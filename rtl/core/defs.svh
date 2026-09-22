
`ifndef DEFS_SVH
`define DEFS_SVH

`define OPC_LOAD    7'b0000011
`define OPC_OPIMM   7'b0010011
`define OPC_AUIPC   7'b0010111
`define OPC_STORE   7'b0100011
`define OPC_OP      7'b0110011
`define OPC_LUI     7'b0110111
`define OPC_BRANCH  7'b1100011
`define OPC_JALR    7'b1100111
`define OPC_JAL     7'b1101111
`define OPC_SYSTEM  7'b1110011
`define OPC_CUSTOM0 7'b0001011

`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLL  4'd2
`define ALU_SLT  4'd3
`define ALU_SLTU 4'd4
`define ALU_XOR  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_OR   4'd8
`define ALU_AND  4'd9
`define ALU_MUL  4'd10

`define WB_ALU 2'd0
`define WB_MEM 2'd1
`define WB_PC4 2'd2

`define AA_RS1  2'd0
`define AA_PC   2'd1
`define AA_ZERO 2'd2

`define BR_NONE 3'd0
`define BR_EQ   3'd1
`define BR_NE   3'd2
`define BR_LT   3'd3
`define BR_GE   3'd4
`define BR_LTU  3'd5
`define BR_GEU  3'd6
`define BR_JUMP 3'd7

`define IMM_I 3'd0
`define IMM_S 3'd1
`define IMM_B 3'd2
`define IMM_U 3'd3
`define IMM_J 3'd4

`define CUS_CDOT 3'd0

`define MRET_INSTR 32'h30200073

`endif
