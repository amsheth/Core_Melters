module stack #(parameter WIDTH = 32, parameter DEPTH = 16)(
    input  logic              clk,
    input  logic              rst,
    input  logic              push,
    input  logic              pop,
    input  logic [WIDTH-1:0]  data_in,
    output logic [WIDTH-1:0]  data_out,
    output logic              empty,
    output logic              full
);

    logic [WIDTH-1:0]        stack [0:DEPTH-1];
    logic [$clog2(DEPTH):0]  stack_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            stack_ptr <= 0;
            empty <= 1;
            full <= 0;

        end else begin
            if (push && !full) begin
                stack[stack_ptr] <= data_in;
                stack_ptr        <= stack_ptr + 1;
                empty            <= 0;

                if (stack_ptr == DEPTH - 1) begin
                    full <= 1;
                end

            end else if (pop && !empty) begin
                stack_ptr <= stack_ptr - 1;
                full      <= 0;

                if (stack_ptr == 1) begin
                    empty <= 1;
                end
            end
        end
    end

    always_comb begin
      if (!empty & pop)
            data_out = stack[stack_ptr - 1];
        else
            data_out = {WIDTH{1'b0}};
    end

endmodule