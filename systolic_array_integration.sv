module systolic_array_integration #(
    parameter DATA_WIDTH = 32,
    parameter M = 3,
    parameter COUNT_MAX = (3*M) + 1
) (
    input wire clk,
    input wire reset,
    input wire start,

    // FIFO signals for weights (from HOST(testbench) to FIFO)
    input  wire [M-1:0]          s_valid_w,    // HOST to FIFO. from slave(HOST) to FIFO
    output wire [M-1:0]          s_ready_w,    // FIFO to HOST. from FIFO to slave(HOST)
    input  wire [DATA_WIDTH-1:0] s_data_w [0:M-1],

    // FIFO signals for activations (from HOST(testbench) to FIFO)
    input  wire [M-1:0]          s_valid_a,
    output wire [M-1:0]          s_ready_a,
    input  wire [DATA_WIDTH-1:0] s_data_a [0:M-1],

    output reg [DATA_WIDTH-1:0] result_out[0:M-1][0:M-1],
    output reg done
);

    reg [1:0] state;
    reg [$clog2(COUNT_MAX):0] cnt;

    localparam IDLE = 2'd0, COMPUTE = 2'd1, DONE = 2'd2;

    wire [DATA_WIDTH-1:0] weight_in [0:M-1];
    wire [DATA_WIDTH-1:0] activation_in [0:M-1];

    wire [DATA_WIDTH-1:0] weight_wire[0:M][0:M-1];
    wire [DATA_WIDTH-1:0] activation_wire[0:M-1][0:M];

    wire [M-1:0]          m_ready_w;    // from systolic array to FIFO.
    wire [M-1:0]          m_ready_a;

    wire [DATA_WIDTH-1:0] m_data_w [0:M-1];
    wire [DATA_WIDTH-1:0] m_data_a [0:M-1];

    // Systolic array signals
    reg [M-1:0]          s_ready_systolic_a; // systolic array(excepted FIFO)'s ready signal. from systolic to activation FIFO
    reg [M-1:0]          s_ready_systolic_w; // systolic array(excepted FIFO)'s ready signal. from systolic to weight FIFO

    // Assign input weights and activations
    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin
            assign weight_wire[0][i] = weight_in[i];
            assign activation_wire[i][0] = activation_in[i];
        end
    endgenerate
    
    // Handshake, FIFO to PE (from FIFO outputs), FIFO's master side
    generate
        for (i = 0; i < M; i = i + 1) begin
            assign weight_in[i]     = (m_ready_w[i]) ? m_data_w[i] : 0;
            assign activation_in[i] = (m_ready_a[i]) ? m_data_a[i] : 0;
        end
    endgenerate

    // Assign m_ready_* = s_ready_systolic_*
    generate
        for (i = 0; i < M; i = i + 1) begin
            assign m_ready_w[i] = s_ready_systolic_w[i]; // connection. (weight     FIFO <-> systolic array)
            assign m_ready_a[i] = s_ready_systolic_a[i]; // connection. (activation FIFO <-> systolic array)
        end
    endgenerate

    // Instantiate PE modules
    generate
        for (i = 0; i < M; i = i + 1) begin : row
            for (j = 0; j < M; j = j + 1) begin : col
                PE #(.DATA_WIDTH(DATA_WIDTH)) pe_unit (
                    .clk(clk),
                    .reset(reset),
                    .weight_north(weight_wire[i][j]),
                    .activation_west(activation_wire[i][j]),

                    .weight_south(weight_wire[i+1][j]),
                    .activation_east(activation_wire[i][j+1]),
                    .result(result_out[i][j])
                );
            end
        end
    endgenerate

    // Instantiate the weight FIFOs
    generate
        for (i = 0; i < M; i = i + 1) begin : weight_fifos
            sync_fifo #(
                .FIFO_CMD_LENGTH(DATA_WIDTH),
                .FIFO_IN_REG(0),  // Input skid buffer, registered output (about 'full' signal)
                .FIFO_OUT_REG(0), // Output skid buffer
                .FIFO_DEPTH(4),
                .FIFO_LOG2_DEPTH(2)
            ) weight_fifo (
                .clk(clk),
                .reset(reset),
                .s_valid(s_valid_w[i]), // from HOST to FIFO
                .s_ready(s_ready_w[i]), // from FIFO to HOST
                .s_data(s_data_w[i]),   // from HOST to FIFO
                .m_valid(), 
                .m_ready(m_ready_w[i]), // from PE(from CNTL) to FIFO
                .m_data(m_data_w[i])    // from FIFO to PE
            );
        end
    endgenerate

    // Instantiate the activation FIFOs
    generate
        for (i = 0; i < M; i = i + 1) begin : activation_fifos
            sync_fifo #(
                .FIFO_CMD_LENGTH(DATA_WIDTH),
                .FIFO_IN_REG(0),
                .FIFO_OUT_REG(0),
                .FIFO_DEPTH(4),
                .FIFO_LOG2_DEPTH(2)
            ) activation_fifo (
                .clk(clk),
                .reset(reset),
                .s_valid(s_valid_a[i]),
                .s_ready(s_ready_a[i]),
                .s_data(s_data_a[i]),
                .m_valid(),
                .m_ready(m_ready_a[i]),
                .m_data(m_data_a[i])
            );
        end
    endgenerate

    integer k;
    // Controller Logic for s_ready
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            cnt <= 0;
            done <= 0;
            for (k = 0; k < M; k = k + 1) begin
                s_ready_systolic_w[k] <= 0;
                s_ready_systolic_a[k] <= 0;
            end
        end 
        
        else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE;
                        cnt <= 0;
                        done <= 0;
                    end
                end

                COMPUTE: begin
                    cnt <= cnt + 1;
                    for (k = 0; k < M; k = k + 1) begin
                        if (cnt >= k && cnt < k + M) begin
                            s_ready_systolic_w[k] <= 1;
                            s_ready_systolic_a[k] <= 1;
                        end 
                        else begin
                            s_ready_systolic_w[k] <= 0;
                            s_ready_systolic_a[k] <= 0;
                        end
                    end
                    if (cnt >= COUNT_MAX) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
