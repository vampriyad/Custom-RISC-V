
module imem #(parameter WORDS = 1024) (
    input  logic [31:0] addr,
    output logic [31:0] rdata
);

    localparam AW = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];

`ifndef SYNTHESIS
    initial begin
        reg [1024*8-1:0] hexfile;
        for (int i = 0; i < WORDS; i++)
            mem[i] = 32'h0000_0013;
        if ($value$plusargs("HEX=%s", hexfile))
            $readmemh(hexfile, mem);
    end
`endif

    assign rdata = mem[addr[AW+1:2]];

endmodule
