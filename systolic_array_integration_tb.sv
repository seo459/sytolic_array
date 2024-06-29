`timescale 1ns / 1ps

module systolic_array_integration_tb;

    localparam DATA_WIDTH = 32;
    localparam M = 3;
    localparam COUNT_MAX = 3 * M + 1;

    // Clock and reset
    logic clk;
    logic reset;

    // Systolic array
    logic [DATA_WIDTH-1:0] result_out [0:M-1][0:M-1];
    logic done;
    logic start;

    // FIFO signals for weights
    logic [M-1:0]           s_valid_w;
    logic [M-1:0]           s_ready_w;
    logic [DATA_WIDTH-1:0]  s_data_w [0:M-1];

    logic [M-1:0]           m_ready_w;
    logic [DATA_WIDTH-1:0]  m_data_w [0:M-1];

    // FIFO signals for activations
    logic [M-1:0]           s_valid_a;
    logic [M-1:0]           s_ready_a;
    logic [DATA_WIDTH-1:0]  s_data_a [0:M-1];

    logic [M-1:0]           m_ready_a;
    logic [DATA_WIDTH-1:0]  m_data_a [0:M-1];

    // Instantiate
    systolic_array_integration #(
        .DATA_WIDTH(DATA_WIDTH),
        .M(M),
        .COUNT_MAX(COUNT_MAX)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start(start),

        .s_valid_w(s_valid_w),
        .s_ready_w(s_ready_w),
        .s_data_w(s_data_w),

        .s_valid_a(s_valid_a),
        .s_ready_a(s_ready_a),
        .s_data_a(s_data_a),

        .result_out(result_out),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize inputs
        reset = 1;
        for (int i = 0; i < M; i++) begin
            s_valid_w[i] = 0;
            s_valid_a[i] = 0;

            s_data_w[i] = 0;
            s_data_a[i] = 0;

            m_ready_w[i] = 0;
            m_ready_a[i] = 0;
        end
        start = 0;

        // Release reset
        #20;
        reset = 0;

        #5;
        // valid = 1
        for (int i = 0; i < M; i++) s_valid_w[i] = 1;
        for (int i = 0; i < M; i++) s_valid_a[i] = 1;

        // Send weights, activations to FIFOs
        s_data_w[0] = 32'd1; s_data_a[0] = 32'd1;
        s_data_w[1] = 32'd2; s_data_a[1] = 32'd2;
        s_data_w[2] = 32'd3; s_data_a[2] = 32'd3;
        #10;

        s_data_w[0] = 32'd4; s_data_a[0] = 32'd4;
        s_data_w[1] = 32'd5; s_data_a[1] = 32'd5;
        s_data_w[2] = 32'd6; s_data_a[2] = 32'd6;   
        #10; 

        s_data_w[0] = 32'd7; s_data_a[0] = 32'd7;
        s_data_w[1] = 32'd8; s_data_a[1] = 32'd8;
        s_data_w[2] = 32'd9; s_data_a[2] = 32'd9;
        #10;

        // valid = 0
        for (int i = 0; i < M; i++) s_valid_w[i] = 0;
        for (int i = 0; i < M; i++) s_valid_a[i] = 0;

        // reading from FIFOs
        #30; start = 1;
        #10; start = 0;

        // Wait for a few clock cycles
        #150;

        // Finish
        $finish;
    end

endmodule
