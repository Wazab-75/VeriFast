module mandelbrotCore #(
    INTEGER_BITS = 8,
    FRACTIONAL_BITS = 24,
    MAX_ITER_WIDTH = 16,
    DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS
)(
    input logic clk_i,
    input logic rst_i,
    input logic start_i,
    input logic signed [DATA_WIDTH-1:0] x0_i,
    input logic signed [DATA_WIDTH-1:0] y0_i,
    input logic [MAX_ITER_WIDTH-1:0] max_iter_i,

    output logic [MAX_ITER_WIDTH-1:0] iter_o,
    output logic done_o
);

    // State registers
    logic signed [DATA_WIDTH-1:0] x_reg, y_reg;
    logic signed [DATA_WIDTH-1:0] x0_reg, y0_reg;
    logic [MAX_ITER_WIDTH-1:0] iter_reg;
    logic running_reg;

    // Stage 1: multiplier outputs
    logic signed [DATA_WIDTH-1:0] x2_s1, y2_s1, xy_s1;
    qMult_sc qMult_x2(.input1_i(x_reg), .input2_i(x_reg), .result_o(x2_s1));
    qMult_sc qMult_y2(.input1_i(y_reg), .input2_i(y_reg), .result_o(y2_s1));
    qMult_sc qMult_xy(.input1_i(x_reg), .input2_i(y_reg), .result_o(xy_s1));

    // Stage 2: pipeline registers
    logic signed [DATA_WIDTH-1:0] x2_s2, y2_s2, xy_s2, x0_s2, y0_s2;
    logic [MAX_ITER_WIDTH-1:0] iter_s2;
    logic running_s2;

    // Stage 3: combinational next state
    logic signed [DATA_WIDTH-1:0] x_next, y_next;
    logic [MAX_ITER_WIDTH-1:0] iter_next;
    logic done_next;

    // Combinational next-state logic
    always_comb begin
        // Default
        x_next = x_reg;
        y_next = y_reg;
        iter_next = iter_reg;
        done_next = 0;

        if (running_s2) begin
            if ((x2_s2 + y2_s2) > (4 <<< FRACTIONAL_BITS)) begin
                done_next = 1;
                iter_next = iter_s2;
            end
            else if (iter_s2 < max_iter_i) begin
                x_next = x2_s2 - y2_s2 + x0_s2;
                y_next = (xy_s2 <<< 1) + y0_s2;
                iter_next = iter_s2 + 1;
                done_next = 0;
            end
            else begin
                done_next = 1;
                iter_next = iter_s2;
            end
        end
    end

    // Sequential logic
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // Reset all state
            x_reg <= 0;
            y_reg <= 0;
            x0_reg <= 0;
            y0_reg <= 0;
            iter_reg <= 0;
            running_reg <= 0;
            done_o <= 0;
            iter_o <= 0;

            x2_s2 <= 0;
            y2_s2 <= 0;
            xy_s2 <= 0;
            x0_s2 <= 0;
            y0_s2 <= 0;
            iter_s2 <= 0;
            running_s2 <= 0;
        end
        else begin
            // Start new calculation
            if (start_i && !running_reg) begin
                x_reg <= x0_i;
                y_reg <= y0_i;
                x0_reg <= x0_i;
                y0_reg <= y0_i;
                iter_reg <= 1;
                running_reg <= 1;
                done_o <= 0;
            end
            // Continue iteration
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

            // Stage 2 pipeline update
            x2_s2 <= x2_s1;
            y2_s2 <= y2_s1;
            xy_s2 <= xy_s1;
            x0_s2 <= x0_reg;
            y0_s2 <= y0_reg;
            iter_s2 <= iter_reg;
            running_s2 <= running_reg;
        end
    end

endmodule
