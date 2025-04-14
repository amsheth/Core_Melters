module regfile
import rv32i_types::*;
 #(
    parameter       WIDTH=PHYS_REG_IDX+1
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,
    input   logic   [31:0]  pd_v, // Comes from CDB
    input   logic   [WIDTH-1:0]   pd_s, // Comes from CDB
    input   logic   [WIDTH-1:0]   ps1_s, ps2_s, ps3_s, ps4_s, ps5_s, ps6_s,
    output  logic   [31:0]  ps1_v, ps2_v, ps3_v, ps4_v, ps5_v, ps6_v
);
    localparam COUNT = 1<<WIDTH;
            logic   [31:0]  data [COUNT];
            logic [WIDTH-1:0] r1,r2;

    always_ff @(posedge clk) begin
        // if (rst) begin
        //     for (int i = 0; i < COUNT; i++) begin
        //         data[i] <= '0;
        //     end
        // end else 
        if (regf_we & (pd_s != '0)) begin
            data[pd_s] <= pd_v;
        end
    end

    always_comb begin
        // TODO: Check transparency in TB
        ps1_v = (ps1_s != '0) ? data[ps1_s] : '0;
        ps2_v = (ps2_s != '0) ? data[ps2_s] : '0;
        ps3_v = (ps3_s != '0) ? data[ps3_s] : '0;
        ps4_v = (ps4_s != '0) ? data[ps4_s] : '0;
        ps5_v = (ps5_s != '0) ? data[ps5_s] : '0;
        ps6_v = (ps6_s != '0) ? data[ps6_s] : '0;
    end

    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         rs1_v <= 'x;
    //         rs2_v <= 'x;
    //     end else begin
    //         // TODO: implement transparency
    //         rs1_v <= (rs1_s != '0) ? data[rs1_s] : '0;
    //         rs2_v <= (rs2_s != '0) ? data[rs2_s] : '0;
    //     end
    // end

endmodule : regfile
