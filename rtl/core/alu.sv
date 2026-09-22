`include "defs.svh"

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,
    output logic [31:0] y,
    output logic        eq,
    output logic        lt,
    output logic        ltu
);

    assign eq  = (a == b);
    assign lt  = ($signed(a) < $signed(b));
    assign ltu = (a < b);

    always_comb begin
        case (op)
            `ALU_ADD:  y = a + b;
            `ALU_SUB:  y = a - b;
            `ALU_SLL:  y = a << b[4:0];
            `ALU_SLT:  y = {31'b0, lt};
            `ALU_SLTU: y = {31'b0, ltu};
            `ALU_XOR:  y = a ^ b;
            `ALU_SRL:  y = a >> b[4:0];
            `ALU_SRA:  y = $unsigned($signed(a) >>> b[4:0]);
            `ALU_OR:   y = a | b;
            `ALU_AND:  y = a & b;
            `ALU_MUL:  y = a * b;
            default:   y = 32'h0;
        endcase
    end

endmodule
