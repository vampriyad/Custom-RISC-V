
module dotp (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic        we,
    input  logic [5:0]  addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic        cus_req,
    output logic [31:0] cus_result
);

    logic [31:0] a [0:3];
    logic [31:0] b [0:3];
    logic [31:0] result;

    logic [31:0] aeff0, aeff1, aeff2, aeff3;
    logic [31:0] beff0, beff1, beff2, beff3;
    assign aeff0 = (req && we && addr == 6'd0) ? wdata : a[0];
    assign aeff1 = (req && we && addr == 6'd1) ? wdata : a[1];
    assign aeff2 = (req && we && addr == 6'd2) ? wdata : a[2];
    assign aeff3 = (req && we && addr == 6'd3) ? wdata : a[3];
    assign beff0 = (req && we && addr == 6'd4) ? wdata : b[0];
    assign beff1 = (req && we && addr == 6'd5) ? wdata : b[1];
    assign beff2 = (req && we && addr == 6'd6) ? wdata : b[2];
    assign beff3 = (req && we && addr == 6'd7) ? wdata : b[3];

    logic [31:0] p0, p1, p2, p3, dot;
    assign p0 = aeff0 * beff0;
    assign p1 = aeff1 * beff1;
    assign p2 = aeff2 * beff2;
    assign p3 = aeff3 * beff3;
    assign dot = (p0 + p1) + (p2 + p3);

    assign cus_result = dot;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a[0] <= 32'h0; a[1] <= 32'h0; a[2] <= 32'h0; a[3] <= 32'h0;
            b[0] <= 32'h0; b[1] <= 32'h0; b[2] <= 32'h0; b[3] <= 32'h0;
            result <= 32'h0;
        end else begin
            if (cus_req)
                result <= dot;
            if (req && we) begin
                case (addr)
                    6'd0: a[0] <= wdata;
                    6'd1: a[1] <= wdata;
                    6'd2: a[2] <= wdata;
                    6'd3: a[3] <= wdata;
                    6'd4: b[0] <= wdata;
                    6'd5: b[1] <= wdata;
                    6'd6: b[2] <= wdata;
                    6'd7: b[3] <= wdata;
                    6'd9: result <= dot;
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        case (addr)
            6'd0: rdata = a[0];
            6'd1: rdata = a[1];
            6'd2: rdata = a[2];
            6'd3: rdata = a[3];
            6'd4: rdata = b[0];
            6'd5: rdata = b[1];
            6'd6: rdata = b[2];
            6'd7: rdata = b[3];
            6'd8: rdata = result;
            default: rdata = 32'h0;
        endcase
    end

endmodule
