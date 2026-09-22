`include "defs.svh"

module core_single #(
    parameter logic [31:0] RESET_ADDR = 32'h0000_0000,
    parameter logic [31:0] IRQ_ADDR   = 32'h0000_0004
) (
    input  logic        clk,
    input  logic        rst_n,

    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    output logic        dmem_re,
    output logic        dmem_we,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,

    output logic        cus_req,
    output logic [2:0]  cus_op,
    output logic [31:0] cus_a,
    output logic [31:0] cus_b,
    input  logic [31:0] cus_result,

    input  logic        irq,

    output logic [31:0] dbg_pc,
    output logic        dbg_instr_retiring
);

    logic [31:0] pc, epc;
    logic        in_handler;

    assign imem_addr = pc;
    logic [31:0] instr;
    assign instr = imem_rdata;

    logic        reg_we, mem_we, alu_b_imm, jalr, is_mret, is_cus, illegal;
    logic [1:0]  wb_sel, alu_a_sel;
    logic [3:0]  alu_op;
    logic [2:0]  br_type, imm_type;

    decoder u_dec (
        .instr     (instr),
        .reg_we    (reg_we),
        .wb_sel    (wb_sel),
        .mem_we    (mem_we),
        .alu_a_sel (alu_a_sel),
        .alu_b_imm (alu_b_imm),
        .alu_op    (alu_op),
        .br_type   (br_type),
        .jalr      (jalr),
        .imm_type  (imm_type),
        .is_mret   (is_mret),
        .is_cus    (is_cus),
        .illegal   (illegal)
    );

    logic [4:0] rs1, rs2, rd;
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd  = instr[11:7];

    logic        rf_we;
    logic [31:0] rf_wdata, rs1_val, rs2_val;

    regfile #(.BYPASS(1'b0)) u_rf (
        .clk    (clk),
        .we     (rf_we),
        .waddr  (rd),
        .wdata  (rf_wdata),
        .raddr1 (rs1),
        .raddr2 (rs2),
        .rdata1 (rs1_val),
        .rdata2 (rs2_val)
    );

    logic [31:0] imm;
    imm_gen u_imm (
        .instr    (instr),
        .imm_type (imm_type),
        .imm      (imm)
    );

    logic [31:0] alu_a, alu_b, alu_y;
    logic        eq, lt, ltu;

    always_comb begin
        case (alu_a_sel)
            `AA_PC:   alu_a = pc;
            `AA_ZERO: alu_a = 32'h0;
            default:  alu_a = rs1_val;
        endcase
    end

    assign alu_b = alu_b_imm ? imm : rs2_val;

    alu u_alu (
        .a  (alu_a),
        .b  (alu_b),
        .op (alu_op),
        .y  (alu_y),
        .eq (eq),
        .lt (lt),
        .ltu(ltu)
    );

    logic br_cond;
    always_comb begin
        case (br_type)
            `BR_EQ:   br_cond = eq;
            `BR_NE:   br_cond = !eq;
            `BR_LT:   br_cond = lt;
            `BR_GE:   br_cond = !lt;
            `BR_LTU:  br_cond = ltu;
            `BR_GEU:  br_cond = !ltu;
            `BR_JUMP: br_cond = 1'b1;
            default:  br_cond = 1'b0;
        endcase
    end

    logic [31:0] br_target;
    assign br_target = jalr ? ((rs1_val + imm) & 32'hFFFF_FFFE) : (pc + imm);

    assign cus_req = is_cus & ~take_irq;
    assign cus_op  = instr[14:12];
    assign cus_a   = rs1_val;
    assign cus_b   = rs2_val;

    logic [31:0] result_ex;
    assign result_ex = is_cus ? cus_result : alu_y;

    assign dmem_re    = (wb_sel == `WB_MEM);
    assign dmem_addr  = alu_y;
    assign dmem_wdata = rs2_val;

    logic take_irq;
    assign take_irq = irq & ~in_handler;

    logic [31:0] wb_data;
    always_comb begin
        case (wb_sel)
            `WB_MEM: wb_data = dmem_rdata;
            `WB_PC4: wb_data = pc + 32'd4;
            default: wb_data = result_ex;
        endcase
    end

    assign rf_we    = reg_we & ~take_irq;
    assign rf_wdata = wb_data;
    assign dmem_we  = mem_we & ~take_irq;

    logic [31:0] pc_next;
    always_comb begin
        if (take_irq)      pc_next = IRQ_ADDR;
        else if (is_mret)  pc_next = epc;
        else if (br_cond)  pc_next = br_target;
        else               pc_next = pc + 32'd4;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc         <= RESET_ADDR;
            epc        <= 32'h0;
            in_handler <= 1'b0;
        end else begin
            pc <= pc_next;
            if (take_irq) begin
                epc        <= pc;
                in_handler <= 1'b1;
            end else if (is_mret) begin
                in_handler <= 1'b0;
            end
        end
    end

    assign dbg_pc             = pc;
    assign dbg_instr_retiring = ~take_irq;

endmodule
