module juliaCore#(
    INTEGER_BITS = 8,
    FRACTIONAL_BITS = 24,
    MAX_ITER_WIDTH = 16
)(
    input logic clk_i,
    input logic rst_i,
    input logic start_i,
    input logic signed [DATA_WIDTH-1:0] zx_i, // Initial z = zx + i*zy
    input logic signed [DATA_WIDTH-1:0] zy_i,
    input logic signed [DATA_WIDTH-1:0] cx_i, // Constant c = cx + i*cy
    input logic signed [DATA_WIDTH-1:0] cy_i,
    input logic [MAX_ITER_WIDTH-1:0] max_iter_i,

    output logic [MAX_ITER_WIDTH-1:0] iter_o,
    output logic done_o
);

localparam int DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS;

logic signed [DATA_WIDTH-1:0] x, y;       // z = x + i*y
logic signed [DATA_WIDTH-1:0] x2, y2, xy; // x^2, y^2, x*y
logic [MAX_ITER_WIDTH-1:0] iter;
logic running;

// Fixed-point multipliers
qMult_sc qMult_x2(
    .input1_i(x),
    .input2_i(x),
    .result_o(x2)
);

qMult_sc qMult_y2(
    .input1_i(y),
    .input2_i(y),
    .result_o(y2)
);

qMult_sc qMult_xy(
    .input1_i(x),
    .input2_i(y),
    .result_o(xy)
);

always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        x <= 0;
        y <= 0;
        iter <= 0;
        done_o <= 0;
        iter_o <= 0;
        running <= 0;
    end else begin
        if (start_i && !running) begin
            x <= zx_i;
            y <= zy_i;
            iter <= 0;
            done_o <= 0;
            running <= 1;
        end
        else if (running) begin
            if (x2 + y2 > 4 << FRACTIONAL_BITS) begin
                done_o <= 1;
                iter_o <= iter + 1;
                running <= 0;
            end
            else if (iter < max_iter_i) begin
                iter <= iter + 1;
                x <= x2 - y2 + cx_i;           // z = z^2 + c
                y <= (xy <<< 1) + cy_i;
            end
            else begin
                done_o <= 1;
                iter_o <= iter;
                running <= 0;
            end
        end
    end
end

endmodule
