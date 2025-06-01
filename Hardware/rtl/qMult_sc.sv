module qMult_sc #(parameter
    INTEGER_BITS = 8,
    FRACTIONAL_BITS = 24
) (
    input logic signed [DATA_WIDTH-1:0] input1_i,
    input logic signed [DATA_WIDTH-1:0] input2_i,
    
    output logic signed [DATA_WIDTH-1:0] result_o
);

localparam int DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS;

localparam logic [2*DATA_WIDTH-1:0] ROUNDING_OFFSET = 1 << (FRACTIONAL_BITS - 1);

logic signed [DATA_WIDTH*2-1:0] mult_result;

always_comb begin
    mult_result = input1_i * input2_i;
    mult_result = mult_result + ROUNDING_OFFSET;  // round to nearest
    result_o = mult_result[DATA_WIDTH + FRACTIONAL_BITS -1 : FRACTIONAL_BITS];  // slice bits
end

endmodule
