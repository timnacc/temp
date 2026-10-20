`timescale 1ns/1ps

module tb_chirp;
    reg clk;
    reg reset;
    reg [7:0] X;
    wire [7:0] Y;
    wire [7:0] combined_y;
    reg [31:0] binary_sample;
    integer input_file;
    integer output_file;
    integer read_status;
    integer sample_count;
    integer previous1;
    integer previous2;
    integer expected;

    fir_filter uut (.X(X), .clk(clk), .reset(reset), .Y(Y));
    fir_filter_combined combined (.X(X), .clk(clk), .reset(reset), .Y(combined_y));

    // One simulation clock period represents one 1 ms sample interval.
    always #500000 clk = ~clk;

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        X = 8'd0;
        sample_count = 0;
        previous1 = 0;
        previous2 = 0;
        input_file = $fopen("X.txt", "r");
        if (input_file == 0)
            $fatal(1, "Cannot open X.txt; run from sim/ after generating the chirp");
        output_file = $fopen("Y.txt", "w");
        if (output_file == 0)
            $fatal(1, "Cannot open Y.txt for writing");

        @(posedge clk);
        #1;
        if (Y !== 8'd0 || combined_y !== 8'd0)
            $fatal(1, "Reset did not clear Y");

        read_status = $fscanf(input_file, "%b", binary_sample);
        while (read_status == 1) begin
            if ((^binary_sample === 1'bx) || binary_sample > 32'd255)
                $fatal(1, "Invalid unsigned sample at row %0d", sample_count + 1);

            @(negedge clk);
            reset = 1'b0;
            X = binary_sample[7:0];
            expected = X / 4 + X / 64 + X / 128
                     + previous1 / 8 + previous1 / 16 + previous1 / 32
                     + previous2 / 2;
            previous2 = previous1;
            previous1 = X;

            @(posedge clk);
            #1;
            if (Y !== expected[7:0])
                $fatal(1, "Chirp mismatch at row %0d: Y=%0d, expected=%0d",
                       sample_count + 1, Y, expected);
            if (combined_y !== Y)
                $fatal(1, "Combined filter differs at chirp row %0d", sample_count + 1);
            $fwrite(output_file, "%08b\n", Y);
            sample_count = sample_count + 1;
            read_status = $fscanf(input_file, "%b", binary_sample);
        end

        if (!$feof(input_file))
            $fatal(1, "Malformed binary input after row %0d", sample_count);
        if (sample_count != 2000)
            $fatal(1, "Expected 2000 chirp samples; read %0d", sample_count);
        $fclose(input_file);
        $fclose(output_file);
        $display("PASS: %0d chirp samples read from X.txt, checked, and written to Y.txt.", sample_count);
        $finish;
    end
endmodule
