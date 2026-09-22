
module uart_rx #(parameter DIV = 868) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] data,
    output logic       ready
);

    logic rx_meta, rx_sync;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    localparam logic [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    logic [1:0] state;

    logic [31:0] baud_cnt;
    logic [2:0]  bitpos;
    logic [7:0]  shreg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            baud_cnt <= 32'd0;
            bitpos   <= 3'd0;
            shreg    <= 8'h0;
            data     <= 8'h0;
            ready    <= 1'b0;
        end else begin
            ready <= 1'b0;
            case (state)
                IDLE: begin
                    if (!rx_sync) begin
                        state    <= START;
                        baud_cnt <= 32'd0;
                    end
                end
                START: begin
                    if (baud_cnt == (DIV / 2) - 1) begin
                        baud_cnt <= 32'd0;
                        if (!rx_sync) begin
                            state  <= DATA;
                            bitpos <= 3'd0;
                        end else
                            state <= IDLE;
                    end else
                        baud_cnt <= baud_cnt + 32'd1;
                end
                DATA: begin
                    if (baud_cnt == DIV - 1) begin
                        baud_cnt <= 32'd0;
                        shreg    <= {rx_sync, shreg[7:1]};
                        if (bitpos == 3'd7)
                            state <= STOP;
                        else
                            bitpos <= bitpos + 3'd1;
                    end else
                        baud_cnt <= baud_cnt + 32'd1;
                end
                STOP: begin
                    if (baud_cnt == DIV - 1) begin
                        baud_cnt <= 32'd0;
                        state    <= IDLE;
                        if (rx_sync) begin
                            data  <= shreg;
                            ready <= 1'b1;
                        end
                    end else
                        baud_cnt <= baud_cnt + 32'd1;
                end
            endcase
        end
    end

endmodule
