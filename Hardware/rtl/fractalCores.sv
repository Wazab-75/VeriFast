module fractalCores#(
    parameter INTEGER_BITS = 8,
    parameter FRACTIONAL_BITS = 24,
    parameter MAX_ITER_WIDTH = 16,
    parameter MANDEL_CORE_COUNT = 2 // (limiting to max of  cores for now) (can go up to 18 theoretically prob stop at 16)
)(
    input logic clk_i,
    input logic rst_i [CORE_COUNT],
    input logic start_i [CORE_COUNT],
    input logic signed [DATA_WIDTH-1:0] x0_i [CORE_COUNT], // c = x0 + i * y0 using Q8.24 representation
    input logic signed [DATA_WIDTH-1:0] y0_i [CORE_COUNT],
    input logic [MAX_ITER_WIDTH-1:0] max_iter_i,

    output logic [MAX_ITER_WIDTH-1:0] iter_o [CORE_COUNT],
    output logic done_o [CORE_COUNT]
);

    localparam int DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS;
    localparam int CORE_COUNT = MANDEL_CORE_COUNT /*+ JULIA_CORE_COUNT*/;

    
    /* ------ INSTANTIATE MANDELBROT CORES ------ */

    genvar i;
    generate
        for (i = 0; i < MANDEL_CORE_COUNT; i++) begin : core_gen
            mandelbrotCore #(
                .INTEGER_BITS(INTEGER_BITS),
                .FRACTIONAL_BITS(FRACTIONAL_BITS),
                .MAX_ITER_WIDTH(MAX_ITER_WIDTH)
            ) core_inst (
                .clk_i(clk_i),
                .rst_i(rst_i[i]),
                .start_i(start_i[i]),
                .x0_i(x0_i[i]),
                .y0_i(y0_i[i]),
                .max_iter_i(max_iter_i),
                .iter_o(iter_o[i]),
                .done_o(done_o[i])
            );
        end
    endgenerate

endmodule
