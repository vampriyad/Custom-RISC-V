
module soc_multi #(
    parameter integer WORDS    = 1024,
    parameter integer UART_DIV = 868
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        uart_rx,
    output logic        uart_tx,
    output logic        exit_valid,
    output logic [31:0] exit_code,
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_instr
);

    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_re, dmem_we;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic        cus_req;
    logic [2:0]  cus_op;
    logic [31:0] cus_a, cus_b, cus_result;
    logic        irq;

    core_multi #(
        .RESET_ADDR (32'h0000_0000),
        .IRQ_ADDR   (32'h0000_0004)
    ) u_core (
        .clk, .rst_n,
        .imem_addr, .imem_rdata,
        .dmem_re, .dmem_we, .dmem_addr, .dmem_wdata, .dmem_rdata,
        .cus_req, .cus_op, .cus_a, .cus_b, .cus_result,
        .irq,
        .dbg_pc (dbg_pc),
        .dbg_instr_retiring ()
    );

    imem #(.WORDS(WORDS)) u_imem (
        .addr  (imem_addr),
        .rdata (imem_rdata)
    );

    assign dbg_instr = imem_rdata;

    logic [3:0] region;
    assign region = dmem_addr[31:28];

    logic ram_sel, uart_sel, timer_sel, dotp_sel, exit_sel;
    assign ram_sel   = (region == 4'h1);
    assign uart_sel  = (region == 4'h2);
    assign timer_sel = (region == 4'h3);
    assign dotp_sel  = (region == 4'h4);
    assign exit_sel  = (region == 4'h5);

    logic bus_req;
    assign bus_req = dmem_re | dmem_we;

    logic [31:0] ram_rdata;
    dmem #(.WORDS(WORDS)) u_dmem (
        .clk   (clk),
        .we    (dmem_we & ram_sel),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .rdata (ram_rdata)
    );

    logic [31:0] uart_rdata;
    uart #(.DIV(UART_DIV)) u_uart (
        .clk, .rst_n,
        .req   (bus_req & uart_sel),
        .we    (dmem_we),
        .addr  (dmem_addr[5:2]),
        .wdata (dmem_wdata),
        .rdata (uart_rdata),
        .rx    (uart_rx),
        .tx    (uart_tx)
    );

    logic [31:0] timer_rdata;
    timer u_timer (
        .clk, .rst_n,
        .req   (bus_req & timer_sel),
        .we    (dmem_we),
        .addr  (dmem_addr[5:2]),
        .wdata (dmem_wdata),
        .rdata (timer_rdata),
        .irq   (irq)
    );

    logic [31:0] dotp_rdata;
    dotp u_dotp (
        .clk, .rst_n,
        .req        (bus_req & dotp_sel),
        .we         (dmem_we),
        .addr       (dmem_addr[7:2]),
        .wdata      (dmem_wdata),
        .rdata      (dotp_rdata),
        .cus_req    (cus_req),
        .cus_result (cus_result)
    );

    always_comb begin
        case (region)
            4'h1:    dmem_rdata = ram_rdata;
            4'h2:    dmem_rdata = uart_rdata;
            4'h3:    dmem_rdata = timer_rdata;
            4'h4:    dmem_rdata = dotp_rdata;
            default: dmem_rdata = 32'h0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exit_valid <= 1'b0;
            exit_code  <= 32'h0;
        end else if (dmem_we && exit_sel) begin
            exit_valid <= 1'b1;
            exit_code  <= dmem_wdata;
        end
    end

endmodule
