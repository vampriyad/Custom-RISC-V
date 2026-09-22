
module timer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic        we,
    input  logic [3:0]  addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        irq
);

    logic [31:0] cnt, cmp;
    logic        ie, pending;

    assign irq = ie & pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= 32'h0;
            cmp     <= 32'hFFFF_FFFF;
            ie      <= 1'b0;
            pending <= 1'b0;
        end else begin
            cnt <= cnt + 32'h1;

            if (cnt == cmp)
                pending <= 1'b1;

            if (req && we) begin
                case (addr)
                    4'd0: cnt <= wdata;
                    4'd1: cmp <= wdata;
                    4'd2: begin
                        ie <= wdata[0];
                        if (wdata[1])
                            pending <= 1'b0;
                    end
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        case (addr)
            4'd0:    rdata = cnt;
            4'd1:    rdata = cmp;
            4'd2:    rdata = {30'h0, pending, ie};
            default: rdata = 32'h0;
        endcase
    end

endmodule
