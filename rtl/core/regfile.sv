
module regfile #(
    parameter bit BYPASS = 1'b1
) (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,
    input  logic [4:0]  raddr1,
    input  logic [4:0]  raddr2,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2
);

    logic [31:0] regs [0:31];

`ifndef SYNTHESIS
    initial begin
        for (int i = 0; i < 32; i++)
            regs[i] = 32'h0;
    end
`endif

    always_ff @(posedge clk) begin
        if (we && (waddr != 5'd0))
            regs[waddr] <= wdata;
    end

    logic hit1, hit2;
    assign hit1 = BYPASS && we && (waddr == raddr1) && (waddr != 5'd0);
    assign hit2 = BYPASS && we && (waddr == raddr2) && (waddr != 5'd0);

    always_comb begin
        if (raddr1 == 5'd0)
            rdata1 = 32'h0;
        else if (hit1)
            rdata1 = wdata;
        else
            rdata1 = regs[raddr1];

        if (raddr2 == 5'd0)
            rdata2 = 32'h0;
        else if (hit2)
            rdata2 = wdata;
        else
            rdata2 = regs[raddr2];
    end

endmodule
