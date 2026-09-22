`include "defs.svh"

module core_multi #(
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

    localparam logic [2:0] S_IF = 3'd0, S_ID = 3'd1, S_EX = 3'd2,
                           S_MEM = 3'd3, S_WB = 3'd4;
    logic [2:0] state, state_next;

    logic [31:0] pc, nextpc_q, epc;
    logic        in_handler;
    logic [31:0] instr;
    logic [31:0] rs1_val, rs2_val;
    logic [31:0] ex_result;
    logic [31:0] load_data;

    assign imem_addr = pc;

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

    logic [31:0] dec_rs1_val, dec_rs2_val;

    regfile #(.BYPASS(1'b0)) u_rf (
        .clk    (clk),
        .we     ((state == S_WB) & reg_we),
        .waddr  (rd),
        .wdata  ((wb_sel == `WB_MEM) ? load_data : ex_result),
        .raddr1 (rs1),
        .raddr2 (rs2),
        .rdata1 (dec_rs1_val),
        .rdata2 (dec_rs2_val)
    );

    logic [31:0] imm;
    imm_gen u_imm (.instr, .imm_type, .imm);

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

    alu u_alu (.a(alu_a), .b(alu_b), .op(alu_op), .y(alu_y),
               .eq, .lt, .ltu);

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

    assign cus_req = (state == S_EX) & is_cus;
    assign cus_op  = `CUS_CDOT;
    assign cus_a   = rs1_val;
    assign cus_b   = rs2_val;

    assign dmem_addr  = ex_result;
    assign dmem_wdata = rs2_val;
    assign dmem_re    = (state == S_MEM) & (wb_sel == `WB_MEM);
    assign dmem_we    = (state == S_MEM) & mem_we;

    logic [31:0] nextpc_comb;
    assign nextpc_comb = is_mret  ? epc
                       : br_cond  ? br_target
                                  : pc + 32'd4;

    always_comb begin
        state_next = S_IF;
        case (state)
            S_IF:  state_next = S_ID;
            S_ID:  state_next = S_EX;
            S_EX:  state_next = mem_we | (wb_sel == `WB_MEM) ? S_MEM
                              : reg_we                     ? S_WB
                                                           : S_IF;
            S_MEM: state_next = reg_we ? S_WB : S_IF;
            S_WB:  state_next = S_IF;
        endcase
    end

    logic retiring;
    assign retiring = (state != S_IF) && (state_next == S_IF);

    logic take_irq;
    assign take_irq = (state == S_IF) & irq & ~in_handler;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IF;
            pc         <= RESET_ADDR;
            nextpc_q   <= 32'h0;
            epc        <= 32'h0;
            in_handler <= 1'b0;
            instr      <= 32'h0000_0013;
            rs1_val    <= 32'h0;
            rs2_val    <= 32'h0;
            ex_result  <= 32'h0;
            load_data  <= 32'h0;
        end else begin
            if (retiring)
                pc <= nextpc_q;

            case (state)
                S_IF: begin
                    if (take_irq) begin
                        epc        <= pc;
                        pc         <= IRQ_ADDR;
                        nextpc_q   <= IRQ_ADDR;
                        in_handler <= 1'b1;
                        state      <= S_IF;
                    end else begin
                        instr <= imem_rdata;
                        state <= S_ID;
                    end
                end

                S_ID: begin
                    rs1_val <= dec_rs1_val;
                    rs2_val <= dec_rs2_val;
                    state   <= S_EX;
                end

                S_EX: begin
                    ex_result <= (wb_sel == `WB_PC4) ? (pc + 32'd4)
                               : is_cus ? cus_result
                                        : alu_y;
                    nextpc_q  <= nextpc_comb;
                    if (is_mret)
                        in_handler <= 1'b0;
                    state <= state_next;
                end

                S_MEM: begin
                    if (wb_sel == `WB_MEM)
                        load_data <= dmem_rdata;
                    state <= state_next;
                end

                S_WB: state <= S_IF;
            endcase

            if ((state == S_EX) && (state_next == S_IF))
                pc <= nextpc_comb;
        end
    end

    assign dbg_pc             = pc;
    assign dbg_instr_retiring = retiring;

endmodule
