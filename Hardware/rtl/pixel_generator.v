
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2024 22:03:08
// Design Name: 
// Module Name: test_block_v
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pixel_generator(
    input           out_stream_aclk,
    input           s_axi_lite_aclk,
    input           axi_resetn,
    input           periph_resetn,
    
    //Stream output
    output [31:0]   out_stream_tdata,
    output [3:0]    out_stream_tkeep,
    output          out_stream_tlast,
    input           out_stream_tready,
    output          out_stream_tvalid,
    output [0:0]    out_stream_tuser, 
    
    //AXI-Lite S
    input [AXI_LITE_ADDR_WIDTH-1:0]     s_axi_lite_araddr,
    output          s_axi_lite_arready,
    input           s_axi_lite_arvalid,
    
    input [AXI_LITE_ADDR_WIDTH-1:0]     s_axi_lite_awaddr,
    output          s_axi_lite_awready,
    input           s_axi_lite_awvalid,
    
    input           s_axi_lite_bready,
    output [1:0]    s_axi_lite_bresp,
    output          s_axi_lite_bvalid,
    
    output [31:0]   s_axi_lite_rdata,
    input           s_axi_lite_rready,
    output [1:0]    s_axi_lite_rresp,
    output          s_axi_lite_rvalid,
    
    input  [31:0]   s_axi_lite_wdata,
    output          s_axi_lite_wready,
    input           s_axi_lite_wvalid
    
);
    
    parameter  REG_FILE_SIZE = 8;
    localparam REG_FILE_AWIDTH = $clog2(REG_FILE_SIZE);
    parameter  AXI_LITE_ADDR_WIDTH = 8;
    
    localparam AWAIT_WADD_AND_DATA = 3'b000;
    localparam AWAIT_WDATA = 3'b001;
    localparam AWAIT_WADD = 3'b010;
    localparam AWAIT_WRITE = 3'b100;
    localparam AWAIT_RESP = 3'b101;
    
    localparam AWAIT_RADD = 2'b00;
    localparam AWAIT_FETCH = 2'b01;
    localparam AWAIT_READ = 2'b10;
    
    localparam AXI_OK = 2'b00;
    localparam AXI_ERR = 2'b10;
    
    reg [31:0]                          regfile [REG_FILE_SIZE-1:0];
    reg [REG_FILE_AWIDTH-1:0]           writeAddr, readAddr;
    reg [31:0]                          readData, writeData;
    reg [1:0]                           readState = AWAIT_RADD;
    reg [2:0]                           writeState = AWAIT_WADD_AND_DATA;
    
    //Read from the register file
    always @(posedge s_axi_lite_aclk) begin
        
        readData <= regfile[readAddr];
    
        if (!axi_resetn) begin
        readState <= AWAIT_RADD;
        end
    
        else case (readState)
    
            AWAIT_RADD: begin
                if (s_axi_lite_arvalid) begin
                    readAddr <= s_axi_lite_araddr[2+:REG_FILE_AWIDTH];
                    readState <= AWAIT_FETCH;
                end
            end
    
            AWAIT_FETCH: begin
                readState <= AWAIT_READ;
            end
    
            AWAIT_READ: begin
                if (s_axi_lite_rready) begin
                    readState <= AWAIT_RADD;
                end
            end
    
            default: begin
                readState <= AWAIT_RADD;
            end
    
        endcase
    end
    
    assign s_axi_lite_arready = (readState == AWAIT_RADD);
    assign s_axi_lite_rresp = (readAddr < REG_FILE_SIZE) ? AXI_OK : AXI_ERR;
    assign s_axi_lite_rvalid = (readState == AWAIT_READ);
    assign s_axi_lite_rdata = readData;
    
    //Write to the register file, use a state machine to track address write, data write and response read events
    always @(posedge s_axi_lite_aclk) begin
    
        if (!axi_resetn) begin
            writeState <= AWAIT_WADD_AND_DATA;
        end
    
        else case (writeState)
    
            AWAIT_WADD_AND_DATA: begin  //Idle, awaiting a write address or data
                case ({s_axi_lite_awvalid, s_axi_lite_wvalid})
                    2'b10: begin
                        writeAddr <= s_axi_lite_awaddr[2+:REG_FILE_AWIDTH];
                        writeState <= AWAIT_WDATA;
                    end
                    2'b01: begin
                        writeData <= s_axi_lite_wdata;
                        writeState <= AWAIT_WADD;
                    end
                    2'b11: begin
                        writeData <= s_axi_lite_wdata;
                        writeAddr <= s_axi_lite_awaddr[2+:REG_FILE_AWIDTH];
                        writeState <= AWAIT_WRITE;
                    end
                    default: begin
                        writeState <= AWAIT_WADD_AND_DATA;
                    end
                endcase        
            end
    
            AWAIT_WDATA: begin //Received address, waiting for data
                if (s_axi_lite_wvalid) begin
                    writeData <= s_axi_lite_wdata;
                    writeState <= AWAIT_WRITE;
                end
            end
    
            AWAIT_WADD: begin //Received data, waiting for address
                if (s_axi_lite_awvalid) begin
                    writeAddr <= s_axi_lite_awaddr[2+:REG_FILE_AWIDTH];
                    writeState <= AWAIT_WRITE;
                end
            end
    
            AWAIT_WRITE: begin
                if (writeAddr == 4) begin
    
                    regfile[4] <= {writeData[31:18], regfile[4][17], writeData[16:0]};
                end else begin
                    regfile[writeAddr] <= writeData;
                end
                writeState <= AWAIT_RESP;
            end
    
            AWAIT_RESP: begin //Wait to send response
                if (s_axi_lite_bready) begin
                    writeState <= AWAIT_WADD_AND_DATA;
                end
            end
    
            default: begin
                writeState <= AWAIT_WADD_AND_DATA;
            end
        endcase
    end
    
    assign s_axi_lite_awready = (writeState == AWAIT_WADD_AND_DATA || writeState == AWAIT_WADD);
    assign s_axi_lite_wready = (writeState == AWAIT_WADD_AND_DATA || writeState == AWAIT_WDATA);
    assign s_axi_lite_bvalid = (writeState == AWAIT_RESP);
    assign s_axi_lite_bresp = (writeAddr < REG_FILE_SIZE) ? AXI_OK : AXI_ERR;
    
    parameter INTEGER_BITS = 8;
    parameter FRACTIONAL_BITS = 24;
    parameter MAX_ITER_WIDTH = 16;
    parameter DATA_WIDTH = INTEGER_BITS + FRACTIONAL_BITS;
    
    parameter MANDEL_CORE_COUNT = 8;
    parameter JULIA_CORE_COUNT = 8;
    parameter CORE_COUNT = MANDEL_CORE_COUNT + JULIA_CORE_COUNT;
    
    //wire [15:0] x_size = regfile[5][15:0];
    //wire [15:0] y_size = regfile[5][31:16];
    
    reg [15:0] x;
    reg [15:0] y;
    
    wire first = (x == 0) & (y==0);
    wire lastx = (x == 1080 - 1);
    wire lasty = (y == 810 - 1);
    wire [7:0] frame = regfile[0];
    
    wire ready;
    reg valid_int;
    reg new_pixel;
    
    wire [CORE_COUNT-1:0] done;
    
    reg signed [(DATA_WIDTH) * (CORE_COUNT) - 1:0] x_0, y_0;
    reg signed [DATA_WIDTH-1:0] x_n, y_n; // next x and y values
    
    wire [(MAX_ITER_WIDTH) * (CORE_COUNT) - 1:0] mandelbrot_iter;
    reg [CORE_COUNT-1:0] core_start;

    reg [MAX_ITER_WIDTH-1:0] iter_count;
    
    // Registers from AXI-Lite
    wire signed [31:0] start_x_0 = regfile[1];
    wire signed [31:0] start_y_0 = regfile[2];
    wire [31:0] step_size = regfile[3];
    wire [15:0] max_iter = regfile[4][15:0];
    wire m_or_j = regfile[4][16];
    wire [DATA_WIDTH-1:0] cx_i = regfile[6][DATA_WIDTH-1:0]; // used only for julia
    wire [DATA_WIDTH-1:0] cy_i = regfile[7][DATA_WIDTH-1:0]; // used only for julia
    
    wire [1:0] colour_mode = regfile[4][19:18];    
    
    always @(posedge out_stream_aclk) begin
        if (periph_resetn) begin
            if (new_pixel) begin
                if (lastx) begin
                    x <= 10'd0;
                    x_n <= start_x_0;
                    if (lasty) begin
                        y <= 9'd0;
                        y_n <= start_y_0;
                        regfile[4][17] <= ~regfile[4][17];
                    end
                    else begin
                        y <= y + 9'd1;
                        y_n <= y_n - step_size;
                    end
                end
                else begin
                    x <= x + 9'd1;
                    x_n <= x_n + step_size;
                end
            end
        end
        else begin
            x <= 0;
            y <= 0;
            x_n <= start_x_0;
            y_n <= start_y_0;
        end
    end
    
    localparam STATE_WIDTH = $clog2(CORE_COUNT+1);
    reg [STATE_WIDTH-1:0] waiting, next_waiting, packer_waiting;
    
    localparam [STATE_WIDTH-1:0] WC0 = 0;
    localparam [STATE_WIDTH-1:0] WC1 = 1;
    localparam [STATE_WIDTH-1:0] WC2 = 2;
    localparam [STATE_WIDTH-1:0] WC3 = 3;
    localparam [STATE_WIDTH-1:0] WC4 = 4;
    localparam [STATE_WIDTH-1:0] WC5 = 5;
    localparam [STATE_WIDTH-1:0] WC6 = 6;
    localparam [STATE_WIDTH-1:0] WC7 = 7;
    localparam [STATE_WIDTH-1:0] PACKER_WAIT = 8;
    localparam [STATE_WIDTH-1:0] RC0 = 10;
    localparam [STATE_WIDTH-1:0] RC1 = 11;
    localparam [STATE_WIDTH-1:0] RC2 = 12;
    localparam [STATE_WIDTH-1:0] RC3 = 13;
    localparam [STATE_WIDTH-1:0] RC4 = 14;
    localparam [STATE_WIDTH-1:0] RC5 = 15;
    localparam [STATE_WIDTH-1:0] RC6 = 16;
    localparam [STATE_WIDTH-1:0] RC7 = 17;
    
    wire [7:0] r, g, b; // rgb values to send to the packer
    
    always @(posedge out_stream_aclk) begin
        if (periph_resetn) begin
            case (waiting)
                WC0: begin
                    if ((done[0] && ~m_or_j) || (done[0 + MANDEL_CORE_COUNT] && m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC1;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC0 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC0 * MAX_ITER_WIDTH +: 16];
                        end
                    end
                    else begin
                        next_waiting <= WC0;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC1: begin
                    if ((done[1] && ~m_or_j) || (done[1 + MANDEL_CORE_COUNT] && m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC2;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
    
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC1 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC1 * MAX_ITER_WIDTH +: 16];
                        end 
                    end
                    else begin
                        next_waiting <= WC1;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC2: begin
                    if ((done[2] && ~m_or_j) || (done[2 + MANDEL_CORE_COUNT] && m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC3;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
    
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC2 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC2 * MAX_ITER_WIDTH +: 16];
                        end 
                    end
                    else begin
                        next_waiting <= WC2;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC3: begin
                    if ((done[3]&!m_or_j) | (done[3 + MANDEL_CORE_COUNT]&m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC4;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC3 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC3 * MAX_ITER_WIDTH +: 16];
                        end
                    end
                    else begin
                        next_waiting <= WC3;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC4: begin
                    if ((done[4]&!m_or_j) | (done[4 + MANDEL_CORE_COUNT]&m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC5;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
    
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC4 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC4 * MAX_ITER_WIDTH +: 16];
                        end 
                    end
                    else begin
                        next_waiting <= WC4;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC5: begin
                    if ((done[5]&!m_or_j) | (done[5 + MANDEL_CORE_COUNT]&m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC6;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
                        
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC5 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC5 * MAX_ITER_WIDTH +: 16];
                        end 
                    end
                    else begin
                        next_waiting <= WC5;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC6: begin
                    if ((done[6]&!m_or_j) | (done[6 + MANDEL_CORE_COUNT]&m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC7;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
    
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC6 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC6 * MAX_ITER_WIDTH +: 16];
                        end 
                    end
                    else begin
                        next_waiting <= WC6;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                WC7: begin
                    if ((done[7]&!m_or_j) | (done[7 + MANDEL_CORE_COUNT]&m_or_j)) begin
                        next_waiting <= PACKER_WAIT;
                        packer_waiting <= WC0;
                        new_pixel <= 1'b1;
                        valid_int <= 1'b1;
    
                        if (m_or_j) begin // julia mode
                            iter_count <= mandelbrot_iter[WC7 * MAX_ITER_WIDTH + MANDEL_CORE_COUNT * MAX_ITER_WIDTH +: 16];
                        end
                        else begin // mandelbrot mode
                            iter_count <= mandelbrot_iter[WC7 * MAX_ITER_WIDTH +: 16];
                        end 
                    end
                    else begin
                        next_waiting <= WC7;
                        new_pixel <= 1'b0;
                    end
                    core_start <= 0;
                end
                PACKER_WAIT: begin
                    if (ready) begin
                        next_waiting <= packer_waiting;
                        valid_int <= 1'b0;
                        new_pixel <= 1'b0;
    
                        if (m_or_j) begin // julia mode
                            if (packer_waiting == WC0) begin // need to restart C7
                                core_start[WC7-1+1 + MANDEL_CORE_COUNT] <= 1'b1;
                                x_0[WC7 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                                y_0[WC7 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                                
                            end
                            else begin
                                core_start[packer_waiting-1 + MANDEL_CORE_COUNT] <= 1'b1;
                                x_0[(packer_waiting-1) * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                                y_0[(packer_waiting-1) * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                            end
                            
                        end
                        else begin // mandelbrot mode
                            if (packer_waiting == WC0) begin // need to restart C7
                                core_start[WC7-1+1] <= 1'b1;
                                x_0[WC7 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                                y_0[WC7 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                                
                            end
                            else begin
                                core_start[packer_waiting-1] <= 1'b1;
                                x_0[(packer_waiting-1) * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                                y_0[(packer_waiting-1) * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                            end
                        end
                    end
                    else begin
                        next_waiting <= PACKER_WAIT;
                        valid_int <= 1'b1;
                        new_pixel <= 1'b0;
                    end
                end
                RC0: begin
                    new_pixel <= 1'b1;
                    x_0[0 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[0 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[0] <= 1'b1;

                    x_0[0 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[0 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[0 + MANDEL_CORE_COUNT] <= 1'b1;

                    next_waiting <= RC1;
                end
                RC1: begin
                    new_pixel <= 1'b1;
                    x_0[1 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[1 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[1] <= 1'b1;
                    core_start[0] <= 1'b0;

                    x_0[1 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[1 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[1 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[0 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= RC2;
                end
                RC2: begin
                    new_pixel <= 1'b1;
                    x_0[2 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[2 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[2] <= 1'b1;
                    core_start[1] <= 1'b0;

                    x_0[2 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[2 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[2 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[1 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= RC3;
                end
                RC3: begin
                    new_pixel <= 1'b1;
                    x_0[3 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[3 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[3] <= 1'b1;
                    core_start[2] <= 1'b0;

                    x_0[3 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[3 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[3 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[2 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= RC4;
                end
                RC4: begin
                    new_pixel <= 1'b1;
                    x_0[4 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[4 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[4] <= 1'b1;
                    core_start[3] <= 1'b0;

                    x_0[4 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[4 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[4 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[3 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= RC5;
                end
                RC5: begin
                    new_pixel <= 1'b1;
                    x_0[5 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[5 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[5] <= 1'b1;
                    core_start[4] <= 1'b0;

                    x_0[5 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[5 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[5 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[4 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= RC6;
                end
                RC6: begin
                    new_pixel <= 1'b1;
                    x_0[6 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[6 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[6] <= 1'b1;
                    core_start[5] <= 1'b0;

                    x_0[6 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[6 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[6 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[5 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= RC7;
                end
                RC7: begin
                    x_0[7 * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[7 * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[7] <= 1'b1;
                    core_start[6] <= 1'b0;

                    x_0[7 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= x_n;
                    y_0[7 * DATA_WIDTH + MANDEL_CORE_COUNT * DATA_WIDTH +: DATA_WIDTH] <= y_n;
                    core_start[7 + MANDEL_CORE_COUNT] <= 1'b1;
                    core_start[6 + MANDEL_CORE_COUNT] <= 1'b0;

                    next_waiting <= WC0;
                end
                default: begin
                    next_waiting <= RC0;
                    valid_int <= 1'b0;
                    new_pixel <= 1'b0;
                end
            endcase
        end
        else begin
            next_waiting <= RC0;
            valid_int <= 1'b0;
            new_pixel <= 1'b0;
            core_start <= 0;
        end
    end
        
    always @(posedge out_stream_aclk) begin
        waiting <= next_waiting;
    end
    
    fractalCores #(
        .INTEGER_BITS(INTEGER_BITS),
        .FRACTIONAL_BITS(FRACTIONAL_BITS),
        .MAX_ITER_WIDTH(MAX_ITER_WIDTH),
        .MANDEL_CORE_COUNT(MANDEL_CORE_COUNT),
        .JULIA_CORE_COUNT(JULIA_CORE_COUNT)
    ) fractalCores (
        .clk_i(out_stream_aclk),
        .rst_i(~periph_resetn),
        .start_i(core_start),
        .max_iter_i(max_iter),
        .x0_i(x_0),
        .y0_i(y_0),
        .cx_i(cx_i), // used only for julia
        .cy_i(cy_i), // used only for julia
        .iter_o(mandelbrot_iter),
        .done_o(done)
    );

    colourMap #(
        .MAX_ITER_WIDTH(MAX_ITER_WIDTH)
    ) colourMap (
        .colour_i(colour_mode),
        .iter_i(iter_count),
        .max_iter_i(max_iter),
        .r_o(r), .g_o(g), .b_o(b)
    );
    
    packer pixel_packer(    .aclk(out_stream_aclk),
                            .aresetn(periph_resetn),
                            .r(r), .g(g), .b(b),
                            .eol(lastx), .in_stream_ready(ready), .valid(valid_int), .sof(first),
                            .out_stream_tdata(out_stream_tdata), .out_stream_tkeep(out_stream_tkeep),
                            .out_stream_tlast(out_stream_tlast), .out_stream_tready(out_stream_tready),
                            .out_stream_tvalid(out_stream_tvalid), .out_stream_tuser(out_stream_tuser) );
endmodule
