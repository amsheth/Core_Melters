module stack #(parameter WIDTH = 32, parameter DEPTH = 16)(
    input  logic              clk,
    input  logic              rst,
    input  bit              push,
    input  bit              pop,
    input  logic [WIDTH-1:0]  data_in,
    output logic [WIDTH-1:0]  data_out,
    output bit              empty
);

    logic [WIDTH-1:0]        stack [DEPTH];
    logic [31:0]  stack_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            stack_ptr <= '0;
            // full <= '0;

        end else begin
            if (push) begin
                stack[($clog2(DEPTH))'(stack_ptr)] <= data_in;

                // if ((stack_ptr) == ($clog2(DEPTH))'(DEPTH)) begin
                //     stack_ptr<=stack_ptr;
                // end
                // else 
                stack_ptr        <= stack_ptr + 1'b1;

            end
            if (pop && !empty) begin
                stack_ptr <= stack_ptr - 1'b1;
                // full      <= '0;
            end
        end
    end

    always_comb begin
        if (!empty & pop)
            data_out = stack[($clog2(DEPTH))'(stack_ptr - 1)];
        else
            data_out = '0;
    end

    assign empty = (stack_ptr=='0);

endmodule
