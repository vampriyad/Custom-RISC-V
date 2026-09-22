module counter #(
    parameter WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    output logic [WIDTH-1:0] q,
    output logic             tick
);
    assign tick = en && (&q);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= {WIDTH{1'b0}};
        else if (en)
            q <= q + {{(WIDTH-1){1'b0}}, 1'b1};
    end
endmodule
