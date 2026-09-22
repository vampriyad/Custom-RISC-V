
module uart_tx #(parameter DIV = 868) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] data,
    input  logic       start,
    output logic       busy,
    output logic       tx
);

    logic [9:0] frame;
    logic [3:0] bitpos;
    logic [31:0] baud_cnt;
    logic active;

    assign busy = active;
    assign tx = active ? frame[0] : 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame   <= 10'h3FF;
            bitpos  <= 4'd0;
            baud_cnt<= 32'd0;
            active  <= 1'b0;
        end else if (!active) begin
            baud_cnt <= 32'd0;
            bitpos   <= 4'd0;
            if (start) begin
                frame  <= {1'b1, data, 1'b0};
                active <= 1'b1;
            end
        end else begin
            if (baud_cnt == DIV - 1) begin
                baud_cnt <= 32'd0;
                frame    <= {1'b1, frame[9:1]};
                if (bitpos == 4'd9)
                    active <= 1'b0;
                else
                    bitpos <= bitpos + 4'd1;
            end else begin
                baud_cnt <= baud_cnt + 32'd1;
            end
        end
    end

endmodule
