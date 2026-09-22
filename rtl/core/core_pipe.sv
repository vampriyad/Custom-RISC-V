`include "defs.svh"

module core_pipe #(
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

    logic [31:0] pc;
    logic [31:0] epc;
    logic        drain, in_handler;

    logic        ifid_valid;
    logic [31:0] ifid_pc, ifid_instr;

    logic        idex_valid;
    logic [31:0] idex_pc, idex_rs1_val, idex_rs2_val, idex_imm;
    logic [4:0]  idex_rd, idex_rs1, idex_rs2;
    logic        idex_reg_we, idex_mem_we, idex_alu_b_imm, idex_jalr;
    logic        idex_is_mret, idex_is_cus;
    logic [1:0]  idex_wb_sel, idex_alu_a_sel;
    logic [3:0]  idex_alu_op;
    logic [2:0]  idex_br_type;

    logic        exmem_valid;
    logic [31:0] exmem_result, exmem_store_data;
    logic [4:0]  exmem_rd;
    logic        exmem_reg_we, exmem_mem_we, exmem_is_mret;
    logic [1:0]  exmem_wb_sel;

    logic        memwb_valid;
    logic [31:0] memwb_result, memwb_mem_data;
    logic [4:0]  memwb_rd;
    logic        memwb_reg_we, memwb_is_mret;
    logic [1:0]  memwb_wb_sel;

    logic [31:0] wb_data;
    logic        wb_we;
    logic [4:0]  wb_rd;

    logic [31:0] mem_result;

    assign imem_addr = pc;

    logic        dec_reg_we, dec_mem_we, dec_alu_b_imm, dec_jalr;
    logic        dec_is_mret, dec_is_cus, dec_illegal;
    logic [1:0]  dec_wb_sel, dec_alu_a_sel;
    logic [3:0]  dec_alu_op;
    logic [2:0]  dec_br_type, dec_imm_type;

    decoder u_dec (
        .instr     (ifid_instr),
        .reg_we    (dec_reg_we),
        .wb_sel    (dec_wb_sel),
        .mem_we    (dec_mem_we),
        .alu_a_sel (dec_alu_a_sel),
        .alu_b_imm (dec_alu_b_imm),
        .alu_op    (dec_alu_op),
        .br_type   (dec_br_type),
        .jalr      (dec_jalr),
        .imm_type  (dec_imm_type),
        .is_mret   (dec_is_mret),
        .is_cus    (dec_is_cus),
        .illegal   (dec_illegal)
    );

    logic [4:0] dec_rs1, dec_rs2, dec_rd;
    assign dec_rs1 = ifid_instr[19:15];
    assign dec_rs2 = ifid_instr[24:20];
    assign dec_rd  = ifid_instr[11:7];

    logic [31:0] dec_imm;
    imm_gen u_imm (
        .instr    (ifid_instr),
        .imm_type (dec_imm_type),
        .imm      (dec_imm)
    );

    logic [31:0] dec_rs1_val, dec_rs2_val;

    regfile #(.BYPASS(1'b1)) u_rf (
        .clk    (clk),
        .we     (wb_we),
        .waddr  (wb_rd),
        .wdata  (wb_data),
        .raddr1 (dec_rs1),
        .raddr2 (dec_rs2),
        .rdata1 (dec_rs1_val),
        .rdata2 (dec_rs2_val)
    );

    logic [31:0] fwd_a, fwd_b;
    always_comb begin
        fwd_a = idex_rs1_val;
        fwd_b = idex_rs2_val;
        if (memwb_valid && memwb_reg_we && (memwb_rd != 5'd0) && (memwb_rd == idex_rs1))
            fwd_a = wb_data;
        if (memwb_valid && memwb_reg_we && (memwb_rd != 5'd0) && (memwb_rd == idex_rs2))
            fwd_b = wb_data;
        if (exmem_valid && exmem_reg_we && (exmem_rd != 5'd0) && (exmem_rd == idex_rs1))
            fwd_a = mem_result;
        if (exmem_valid && exmem_reg_we && (exmem_rd != 5'd0) && (exmem_rd == idex_rs2))
            fwd_b = mem_result;
    end

    logic [31:0] alu_a, alu_b, alu_y;
    logic        eq, lt, ltu;

    always_comb begin
        case (idex_alu_a_sel)
            `AA_PC:   alu_a = idex_pc;
            `AA_ZERO: alu_a = 32'h0;
            default:  alu_a = fwd_a;
        endcase
    end
    assign alu_b = idex_alu_b_imm ? idex_imm : fwd_b;

    alu u_alu (
        .a(alu_a), .b(alu_b), .op(idex_alu_op), .y(alu_y),
        .eq(eq), .lt(lt), .ltu(ltu)
    );

    logic br_cond;
    always_comb begin
        case (idex_br_type)
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
    assign br_target = idex_jalr ? ((fwd_a + idex_imm) & 32'hFFFF_FFFE)
                                 : (idex_pc + idex_imm);

    assign cus_req = idex_valid & idex_is_cus;
    assign cus_op  = `CUS_CDOT;
    assign cus_a   = fwd_a;
    assign cus_b   = fwd_b;

    logic [31:0] wb_val_ex;
    assign wb_val_ex = (idex_wb_sel == `WB_PC4) ? (idex_pc + 32'd4)
                     : idex_is_cus ? cus_result
                     : alu_y;

    logic        ex_redirect;
    logic [31:0] ex_target;
    assign ex_redirect = idex_valid & (br_cond | idex_is_mret);
    assign ex_target   = idex_is_mret ? epc : br_target;

    assign dmem_addr  = exmem_result;
    assign dmem_wdata = exmem_store_data;
    assign dmem_we    = exmem_valid & exmem_mem_we;
    assign dmem_re    = exmem_valid & (exmem_wb_sel == `WB_MEM);

    assign mem_result = (exmem_wb_sel == `WB_MEM) ? dmem_rdata : exmem_result;

    assign wb_data = (memwb_wb_sel == `WB_MEM) ? memwb_mem_data : memwb_result;
    assign wb_we   = memwb_valid & memwb_reg_we;
    assign wb_rd   = memwb_rd;

    logic        start_drain, pipe_empty, enter_handler, kill_fetch;
    logic [31:0] pc_next;

    assign pipe_empty    = ~ifid_valid & ~idex_valid & ~exmem_valid & ~memwb_valid;
    assign start_drain   = irq & ~in_handler & ~drain;
    assign enter_handler = drain & pipe_empty;
    assign kill_fetch    = ex_redirect | drain | start_drain;

    always_comb begin
        if (enter_handler)            pc_next = IRQ_ADDR;
        else if (ex_redirect)         pc_next = ex_target;
        else if (drain | start_drain) pc_next = pc;
        else                          pc_next = pc + 32'd4;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc             <= RESET_ADDR;
            epc            <= 32'h0;
            drain          <= 1'b0;
            in_handler     <= 1'b0;
            ifid_valid     <= 1'b0;
            ifid_pc        <= 32'h0;
            ifid_instr     <= 32'h0000_0013;
            idex_valid     <= 1'b0;
            idex_pc        <= 32'h0;
            idex_rs1_val   <= 32'h0;
            idex_rs2_val   <= 32'h0;
            idex_imm       <= 32'h0;
            idex_rd        <= 5'd0;
            idex_rs1       <= 5'd0;
            idex_rs2       <= 5'd0;
            idex_reg_we    <= 1'b0;
            idex_mem_we    <= 1'b0;
            idex_alu_b_imm <= 1'b0;
            idex_jalr      <= 1'b0;
            idex_is_mret   <= 1'b0;
            idex_is_cus    <= 1'b0;
            idex_wb_sel    <= 2'd0;
            idex_alu_a_sel <= 2'd0;
            idex_alu_op    <= 4'd0;
            idex_br_type   <= 3'd0;
            exmem_valid     <= 1'b0;
            exmem_result    <= 32'h0;
            exmem_store_data<= 32'h0;
            exmem_rd        <= 5'd0;
            exmem_reg_we    <= 1'b0;
            exmem_mem_we    <= 1'b0;
            exmem_wb_sel    <= 2'd0;
            exmem_is_mret   <= 1'b0;
            memwb_valid    <= 1'b0;
            memwb_result   <= 32'h0;
            memwb_mem_data <= 32'h0;
            memwb_rd       <= 5'd0;
            memwb_reg_we   <= 1'b0;
            memwb_wb_sel   <= 2'd0;
            memwb_is_mret  <= 1'b0;
        end else begin
            pc <= pc_next;
            if (enter_handler) begin
                epc        <= pc;
                in_handler <= 1'b1;
                drain      <= 1'b0;
            end else if (start_drain) begin
                drain <= 1'b1;
            end
            if (memwb_valid && memwb_is_mret)
                in_handler <= 1'b0;

            if (kill_fetch) begin
                ifid_valid <= 1'b0;
                ifid_pc    <= pc;
                ifid_instr <= 32'h0000_0013;
            end else begin
                ifid_valid <= 1'b1;
                ifid_pc    <= pc;
                ifid_instr <= imem_rdata;
            end

            if (ex_redirect) begin
                idex_valid <= 1'b0;
            end else begin
                idex_valid     <= ifid_valid;
                idex_pc        <= ifid_pc;
                idex_rs1_val   <= dec_rs1_val;
                idex_rs2_val   <= dec_rs2_val;
                idex_imm       <= dec_imm;
                idex_rd        <= dec_rd;
                idex_rs1       <= dec_rs1;
                idex_rs2       <= dec_rs2;
                idex_reg_we    <= dec_reg_we;
                idex_mem_we    <= dec_mem_we;
                idex_alu_b_imm <= dec_alu_b_imm;
                idex_jalr      <= dec_jalr;
                idex_is_mret   <= dec_is_mret;
                idex_is_cus    <= dec_is_cus;
                idex_wb_sel    <= dec_wb_sel;
                idex_alu_a_sel <= dec_alu_a_sel;
                idex_alu_op    <= dec_alu_op;
                idex_br_type   <= dec_br_type;
            end

            exmem_valid      <= idex_valid;
            exmem_result     <= wb_val_ex;
            exmem_store_data <= fwd_b;
            exmem_rd         <= idex_rd;
            exmem_reg_we     <= idex_reg_we;
            exmem_mem_we     <= idex_mem_we;
            exmem_wb_sel     <= idex_wb_sel;
            exmem_is_mret    <= idex_is_mret;

            memwb_valid    <= exmem_valid;
            memwb_result   <= exmem_result;
            memwb_mem_data <= mem_result;
            memwb_rd       <= exmem_rd;
            memwb_reg_we   <= exmem_reg_we;
            memwb_wb_sel   <= exmem_wb_sel;
            memwb_is_mret  <= exmem_is_mret;
        end
    end

    assign dbg_pc             = pc;
    assign dbg_instr_retiring = memwb_valid;

endmodule
