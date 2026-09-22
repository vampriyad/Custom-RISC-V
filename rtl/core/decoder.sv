`include "defs.svh"

module decoder (
    input  logic [31:0] instr,

    output logic        reg_we,
    output logic [1:0]  wb_sel,
    output logic        mem_we,
    output logic [1:0]  alu_a_sel,
    output logic        alu_b_imm,
    output logic [3:0]  alu_op,
    output logic [2:0]  br_type,
    output logic        jalr,
    output logic [2:0]  imm_type,
    output logic        is_mret,
    output logic        is_cus,
    output logic        illegal
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin
        reg_we    = 1'b0;
        wb_sel    = `WB_ALU;
        mem_we    = 1'b0;
        alu_a_sel = `AA_RS1;
        alu_b_imm = 1'b0;
        alu_op    = `ALU_ADD;
        br_type   = `BR_NONE;
        jalr      = 1'b0;
        imm_type  = `IMM_I;
        is_mret   = 1'b0;
        is_cus    = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            `OPC_LUI: begin
                reg_we    = 1'b1;
                alu_a_sel = `AA_ZERO;
                alu_b_imm = 1'b1;
                alu_op    = `ALU_ADD;
                imm_type  = `IMM_U;
            end

            `OPC_AUIPC: begin
                reg_we    = 1'b1;
                alu_a_sel = `AA_PC;
                alu_b_imm = 1'b1;
                alu_op    = `ALU_ADD;
                imm_type  = `IMM_U;
            end

            `OPC_JAL: begin
                reg_we   = 1'b1;
                wb_sel   = `WB_PC4;
                br_type  = `BR_JUMP;
                imm_type = `IMM_J;
            end

            `OPC_JALR: begin
                if (funct3 == 3'b000) begin
                    reg_we   = 1'b1;
                    wb_sel   = `WB_PC4;
                    br_type  = `BR_JUMP;
                    jalr     = 1'b1;
                    imm_type = `IMM_I;
                end else
                    illegal = 1'b1;
            end

            `OPC_BRANCH: begin
                imm_type = `IMM_B;
                case (funct3)
                    3'b000: br_type = `BR_EQ;
                    3'b001: br_type = `BR_NE;
                    3'b100: br_type = `BR_LT;
                    3'b101: br_type = `BR_GE;
                    3'b110: br_type = `BR_LTU;
                    3'b111: br_type = `BR_GEU;
                    default: illegal = 1'b1;
                endcase
            end

            `OPC_LOAD: begin
                if (funct3 == 3'b010) begin
                    reg_we    = 1'b1;
                    wb_sel    = `WB_MEM;
                    alu_b_imm = 1'b1;
                    alu_op    = `ALU_ADD;
                    imm_type  = `IMM_I;
                end else
                    illegal = 1'b1;
            end

            `OPC_STORE: begin
                if (funct3 == 3'b010) begin
                    mem_we    = 1'b1;
                    alu_b_imm = 1'b1;
                    alu_op    = `ALU_ADD;
                    imm_type  = `IMM_S;
                end else
                    illegal = 1'b1;
            end

            `OPC_OPIMM: begin
                reg_we    = 1'b1;
                alu_b_imm = 1'b1;
                imm_type  = `IMM_I;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    3'b001: begin
                        alu_op = `ALU_SLL;
                        if (funct7 != 7'b0000000) illegal = 1'b1;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)      alu_op = `ALU_SRL;
                        else if (funct7 == 7'b0100000) alu_op = `ALU_SRA;
                        else illegal = 1'b1;
                    end
                endcase
            end

            `OPC_OP: begin
                reg_we = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)      alu_op = `ALU_ADD;
                        else if (funct7 == 7'b0100000) alu_op = `ALU_SUB;
                        else if (funct7 == 7'b0000001) alu_op = `ALU_MUL;
                        else illegal = 1'b1;
                    end
                    3'b001: begin alu_op = `ALU_SLL;  if (funct7 != 7'b0000000) illegal = 1'b1; end
                    3'b010: begin alu_op = `ALU_SLT;  if (funct7 != 7'b0000000) illegal = 1'b1; end
                    3'b011: begin alu_op = `ALU_SLTU; if (funct7 != 7'b0000000) illegal = 1'b1; end
                    3'b100: begin alu_op = `ALU_XOR;  if (funct7 != 7'b0000000) illegal = 1'b1; end
                    3'b101: begin
                        if (funct7 == 7'b0000000)      alu_op = `ALU_SRL;
                        else if (funct7 == 7'b0100000) alu_op = `ALU_SRA;
                        else illegal = 1'b1;
                    end
                    3'b110: begin alu_op = `ALU_OR;  if (funct7 != 7'b0000000) illegal = 1'b1; end
                    3'b111: begin alu_op = `ALU_AND; if (funct7 != 7'b0000000) illegal = 1'b1; end
                endcase
            end

            `OPC_SYSTEM: begin
                if (instr == `MRET_INSTR)
                    is_mret = 1'b1;
                else
                    illegal = 1'b1;
            end

            `OPC_CUSTOM0: begin
                if (funct3 == `CUS_CDOT) begin
                    reg_we = 1'b1;
                    wb_sel = `WB_ALU;
                    is_cus = 1'b1;
                end else
                    illegal = 1'b1;
            end

            default: illegal = 1'b1;
        endcase

        if (illegal) begin
            reg_we  = 1'b0;
            mem_we  = 1'b0;
            br_type = `BR_NONE;
            is_mret = 1'b0;
            is_cus  = 1'b0;
        end
    end

endmodule
