
module dmem #(parameter WORDS = 1024) (
    input  logic        clk,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    localparam AW = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];

`ifndef SYNTHESIS
    initial begin
        reg [1024*8-1:0] hexfile;
        for (int i = 0; i < WORDS; i++)
            mem[i] = 32'h0;
        if ($value$plusargs("DATA=%s", hexfile))
            $readmemh(hexfile, mem);
    end
`endif

    always_ff @(posedge clk) begin
        if (we)
            mem[addr[AW+1:2]] <= wdata;
    end

    assign rdata = mem[addr[AW+1:2]];

endmodule
