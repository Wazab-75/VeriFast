module colourMap#(
    MAX_ITER_WIDTH = 16
)(
    input logic [MAX_ITER_WIDTH-1:0] max_iter_i,
    input logic [MAX_ITER_WIDTH-1:0] iter_i,
    input logic [1:0] colour_i,
    output logic [7:0] r_o,
    output logic [7:0] g_o,
    output logic [7:0] b_o
);

    logic [15:0] iter_scaled;

    always_comb begin
        iter_scaled = iter_i;
        if (max_iter_i == 0) begin
            r_o = 0;
            g_o = 0;
            b_o = 0;
        end
        else begin
            if (max_iter_i[15] == 1) iter_scaled = iter_scaled >> 8;
            else if (max_iter_i[14] == 1) iter_scaled = iter_scaled >> 7;
            else if (max_iter_i[13] == 1) iter_scaled = iter_scaled >> 6;
            else if (max_iter_i[12] == 1) iter_scaled = iter_scaled >> 5;
            else if (max_iter_i[11] == 1) iter_scaled = iter_scaled >> 4;
            else if (max_iter_i[10] == 1) iter_scaled = iter_scaled >> 3;
            else if (max_iter_i[9] == 1) iter_scaled = iter_scaled >> 2;
            else if (max_iter_i[8] == 1) iter_scaled = iter_scaled >> 1;
            else if (max_iter_i[7] == 1) iter_scaled = iter_scaled;
            else if (max_iter_i[6] == 1) iter_scaled = iter_scaled << 1;
            else if (max_iter_i[5] == 1) iter_scaled = iter_scaled << 2;
            else if (max_iter_i[4] == 1) iter_scaled = iter_scaled << 3;
            else if (max_iter_i[3] == 1) iter_scaled = iter_scaled << 4;
            else if (max_iter_i[2] == 1) iter_scaled = iter_scaled << 5;
            else if (max_iter_i[1] == 1) iter_scaled = iter_scaled << 6;
            else if (max_iter_i[0] == 1) iter_scaled = iter_scaled << 7;

            if (iter_i == max_iter_i) begin
                r_o = 0;
                g_o = 0;
                b_o = 0;
            end
            else begin
                case(colour_i)
                    2'b00: begin
                        r_o = iter_scaled[7:0];
                        g_o = iter_scaled[7:0];
                        if (iter_scaled[7:0] <= 8'hC8) b_o = 8'hC8 - (iter_scaled[7:0] << 2);
                        else b_o = 8'h00;
                    end
                    2'b01: begin
                        r_o = iter_scaled[7:0];
                        if (iter_scaled[7:0] <= 8'hC8) g_o = 8'hC8 - (iter_scaled[7:0] << 2);
                        else g_o = 8'h00;
                        b_o = iter_scaled[7:0];
                    end
                    2'b10: begin
                        if (iter_scaled[7:0] <= 8'hC8) r_o = 8'hC8 - (iter_scaled[7:0] << 2);
                        else r_o = 8'h00;
                        g_o = iter_scaled[7:0];
                        b_o = iter_scaled[7:0];
                    end
                    default: begin
                        r_o = iter_scaled[7:0];
                        g_o = iter_scaled[7:0];
                        if (iter_scaled[7:0] <= 8'hC8) b_o = 8'hC8 - (iter_scaled[7:0] << 2);
                        else b_o = 8'h00;                  
                    end
                endcase
            end
        end
    end
endmodule
