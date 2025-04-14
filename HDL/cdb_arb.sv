module cdb_arb 
import rv32i_types::*; 
#(
    // parameter NUM_LOAD_STORE = 1,
    // parameter NUM_ALU = 1,
    // parameter NUM_MULT = 1,
    // parameter NUM_DIV = 1,
    // parameter NUM_BRANCH = 1,
    parameter NUM_FU = 2
)
(
    // input   logic clk,
    // input   logic rst,
    input   cdb_entry_t cdb_value [NUM_FU], 
    input   logic FU_ready [NUM_FU],
    input   logic branch_mispredict,
    output  logic [NUM_FU-1:0] select,
    output  cdb_entry_t cdb_arb_output
);

// logic [NUM_FU-1:0] select_fu_reg; // 001 -> ALU, 010 -> MULT, 100 -> DIV

// always_ff @(posedge clk) begin
//     if (rst) begin
//         select_fu_reg <= (NUM_FU)'('0 +1'b1);
//     end else begin
//         select_fu_reg <= {select_fu_reg[NUM_FU-2:0], select_fu_reg[NUM_FU-1]};
//     end
// end

/**
This module needs to do the following:

1. Check which FUs are ready to write to the CDB
2. Pick the FU which should be written to the CDB (use the select signal to do so)
3. Take the necessary values from the FU
4. Broadcast the value onto the CDB

**/

// always_comb begin
//     cdb_arb_output = '0;
//     select = '0;

//     if (~branch_mispredict) begin
//         for (int i=0; i<NUM_FU;i++) begin
//             if (FU_ready[i]&&select_fu_reg[i]) begin
//                 cdb_arb_output = cdb_value[i];
//                 select[i] = '1;
//                 // cdb_arb_output.valid = '1;
//                 break; 
//             end
//         end
//     end
// end

always_comb begin
    cdb_arb_output = '0;
    select = '0;

    if (~branch_mispredict) begin
        for (int i=0; i<NUM_FU;i++) begin
            if (FU_ready[i]) begin
                cdb_arb_output = cdb_value[i];
                select[i] = '1;
                // cdb_arb_output.valid = '1;
                break; 
            end
        end
    end
end

endmodule
