
module uart #(parameter DIV = 868) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic        we,
    input  logic [3:0]  addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic        rx,
    output logic        tx
);

    logic [7:0] tx_data;
    logic       tx_start, tx_busy;
    logic [7:0] rx_data;
    logic       rx_ready, rx_avail;

    uart_tx #(.DIV(DIV)) u_tx (
        .clk, .rst_n,
        .data  (tx_data),
        .start (tx_start),
        .busy  (tx_busy),
        .tx
    );

    uart_rx #(.DIV(DIV)) u_rx (
        .clk, .rst_n,
        .rx,
        .data  (rx_data),
        .ready (rx_ready)
    );

    logic [7:0] tx_hold;
    logic       tx_pending;

    assign tx_start = tx_pending && !tx_busy;
    assign tx_data  = tx_hold;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_hold    <= 8'h0;
            tx_pending <= 1'b0;
            rx_avail   <= 1'b0;
        end else begin
            if (tx_pending && !tx_busy)
                tx_pending <= 1'b0;
            if (req && we && (addr == 4'd0) && (!tx_busy) && (!tx_pending)) begin
                tx_hold    <= wdata[7:0];
                tx_pending <= 1'b1;
            end
            if (rx_ready) begin
                rx_avail <= 1'b1;
            end
            if (req && !we && (addr == 4'd2))
                rx_avail <= 1'b0;
        end
    end

    logic [7:0] rx_hold;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_hold <= 8'h0;
        else if (rx_ready)
            rx_hold <= rx_data;
    end

    always_comb begin
        case (addr)
            4'd0:    rdata = {24'h0, rx_hold};
            4'd1:    rdata = {30'h0, rx_avail, tx_busy};
            4'd2:    rdata = {24'h0, rx_hold};
            default: rdata = 32'h0;
        endcase
    end

endmodule
