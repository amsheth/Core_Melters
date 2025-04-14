module priority_enc #(
  parameter COUNT=1)(
    input logic [COUNT-1:0] in,
    output logic [$clog2(COUNT)-1:0] out
  );
  // integer i;
  // integer i;
  always_comb begin
    out = '0; // default value if 'in' is all 0's
    for (int i=COUNT-1; i>=0; i=i-1) begin
        if (in[unsigned'(i)]) begin 
        out = ($clog2(COUNT))'(unsigned'(i));
        end
    end
        
  end
endmodule
