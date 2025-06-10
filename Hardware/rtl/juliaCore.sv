module juliaCore #(
    INTEGER_BITS = 8,
    FRACTIONAL_BITS = 24,
    MAX_ITER_WIDTH = 16,
    DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS
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

    logic signed [DATA_WIDTH-1:0] x_reg, y_reg;
    logic signed [DATA_WIDTH-1:0] cx_reg, cy_reg;
    logic [MAX_ITER_WIDTH-1:0] iter_reg;
    logic running_reg;

    // Stage 1: multiplier results
    logic signed [DATA_WIDTH-1:0] x2_s1, y2_s1, xy_s1;
    qMult_sc qMult_x2(.input1_i(x_reg), .input2_i(x_reg), .result_o(x2_s1));
    qMult_sc qMult_y2(.input1_i(y_reg), .input2_i(y_reg), .result_o(y2_s1));
    qMult_sc qMult_xy(.input1_i(x_reg), .input2_i(y_reg), .result_o(xy_s1));

    // Stage 2: combinational next-state logic
    logic signed [DATA_WIDTH-1:0] x_next, y_next;
    logic [MAX_ITER_WIDTH-1:0] iter_next;
    logic done_next;

    always_comb begin
        x_next = x_reg;
        y_next = y_reg;
        iter_next = iter_reg;
        done_next = 0;

        if (running_reg) begin
            if ((x2_s1 + y2_s1) > (4 <<< FRACTIONAL_BITS)) begin
                done_next = 1;
                iter_next = iter_reg;
            end
            else if (iter_reg < max_iter_i) begin
                x_next = x2_s1 - y2_s1 + cx_reg;
                y_next = (xy_s1 <<< 1) + cy_reg;
                iter_next = iter_reg + 1;
                done_next = 0;
            end
            else begin
                done_next = 1;
                iter_next = iter_reg;
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            x_reg <= 0;
            y_reg <= 0;
            cx_reg <= 0;
            cy_reg <= 0;
            iter_reg <= 0;
            running_reg <= 0;
            done_o <= 0;
            iter_o <= 0;
        end
        else begin
            if (start_i && !running_reg) begin
                x_reg <= zx_i;
                y_reg <= zy_i;
                cx_reg <= cx_i;
                cy_reg <= cy_i;
                iter_reg <= 0;
                running_reg <= 1;
                done_o <= 0;
            end
            else if (running_reg) begin
                x_reg <= x_next;
                y_reg <= y_next;
                iter_reg <= iter_next;

                if (done_next) begin
                    done_o <= 1;
                    iter_o <= iter_next;
                    running_reg <= 0;
                end
            end
        end
    end

endmodule
