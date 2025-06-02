module fractalCores #(
    parameter INTEGER_BITS = 8,
    parameter FRACTIONAL_BITS = 24,
    parameter MAX_ITER_WIDTH = 16,
    parameter MANDEL_CORE_COUNT = 10,
    parameter JULIA_CORE_COUNT = 10
)(
    input wire clk_i,
    
    input wire [MANDEL_CORE_COUNT + JULIA_CORE_COUNT - 1:0] rst_i,
    input wire [MANDEL_CORE_COUNT + JULIA_CORE_COUNT - 1:0] start_i,

    input wire signed [(INTEGER_BITS + FRACTIONAL_BITS) * (MANDEL_CORE_COUNT + JULIA_CORE_COUNT) - 1:0] x0_i,
    input wire signed [(INTEGER_BITS + FRACTIONAL_BITS) * (MANDEL_CORE_COUNT + JULIA_CORE_COUNT) - 1:0] y0_i,
    input wire signed [INTEGER_BITS+FRACTIONAL_BITS-1:0] cx_i,
    input wire signed [INTEGER_BITS+FRACTIONAL_BITS-1:0] cy_i,

    input wire [MAX_ITER_WIDTH-1:0] max_iter_i,

    output wire [(MAX_ITER_WIDTH) * (MANDEL_CORE_COUNT + JULIA_CORE_COUNT) - 1:0] iter_o,
    output wire [MANDEL_CORE_COUNT + JULIA_CORE_COUNT - 1:0] done_o
);

    parameter DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS;
    parameter CORE_COUNT = MANDEL_CORE_COUNT + JULIA_CORE_COUNT;

    genvar i;
    generate
        for (i = 0; i < MANDEL_CORE_COUNT; i = i + 1) begin : mandelbrot_core_gen
            mandelbrotCore #(
                .INTEGER_BITS(INTEGER_BITS),
                .FRACTIONAL_BITS(FRACTIONAL_BITS),
                .MAX_ITER_WIDTH(MAX_ITER_WIDTH)
            ) 
            core_inst (
                .clk_i(clk_i),
                .rst_i(rst_i[i]),
                .start_i(start_i[i]),
                .x0_i(x0_i[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH]),
                .y0_i(y0_i[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH]),
                .max_iter_i(max_iter_i),
                .iter_o(iter_o[(i+1)*MAX_ITER_WIDTH-1 -: MAX_ITER_WIDTH]),
                .done_o(done_o[i])
            );
        end
    endgenerate

    genvar j;
    generate
        for (j = MANDEL_CORE_COUNT; j < CORE_COUNT; j++) begin : julia_core_gen
            juliaCore #(
                .INTEGER_BITS(INTEGER_BITS),
                .FRACTIONAL_BITS(FRACTIONAL_BITS),
                .MAX_ITER_WIDTH(MAX_ITER_WIDTH)
            )
            core_inst (
                .clk_i(clk_i),
                .rst_i(rst_i[j]),
                .start_i(start_i[j]),
                .cx_i(cx_i),
                .cy_i(cy_i),
                .zx_i(x0_i[(j+1)*DATA_WIDTH-1 -: DATA_WIDTH]),
                .zy_i(y0_i[(j+1)*DATA_WIDTH-1 -: DATA_WIDTH]),
                .max_iter_i(max_iter_i),
                .iter_o(iter_o[(j+1)*MAX_ITER_WIDTH-1 -: MAX_ITER_WIDTH]),
                .done_o(done_o[j])
            );
        end
    endgenerate

endmodule
