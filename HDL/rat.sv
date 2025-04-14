// Ideas to improve: 
// 1) Allocate new physical registers when the current pointed physical register is not busy -- maybe caution on special cases such as on (add r5, r5, r5; add r3, r4, r5)

module RAT import rv32i_types::*; #(
    parameter RAT_ARCH_REG_IDX = ARCH_REG_IDX,
    parameter RAT_PHYS_REG_IDX = PHYS_REG_IDX,
    parameter NUM_RAT_ENTRIES = NUM_ARCH_REG
)(
    input clk, rst,

    input decode_rename_to_RAT_t        decode_to_rat,
    input cdb_entry_t                   cdb_to_rat,
    input cdb_entry_t                   cdb_to_rat_2,
    input logic                         branch_mispredict,
    input logic [RAT_PHYS_REG_IDX:0]    rrf_to_rat_table [NUM_ARCH_REG],

    output RAT_to_decode_rename_t       rat_to_decode
);

logic [RAT_PHYS_REG_IDX : 0]    rat_table  [NUM_ARCH_REG];
// NOTE: BUSY IS THE INVERSE OF VALID
logic                           busy       [1<<(RAT_PHYS_REG_IDX+1)];

always_comb begin

    //  How to handle cdb write, decode read, decode write to the same address?
    //  DECODE READ and WRITE TO SAME PS, then this is only possible if the new value 
    //          of a register is based on its current value (ex. add r5, r5, r5)
    //          So, no transparency.
    //  DECODE WRITE and CDB WRITE TO SAME PS, then this is an error, as a register 
    //          yet to be committed shouldn't be used as a freeVariable.
    //          So, raise assert
    //  DECODE READ and CDB WRITE, at worst case, the valid signal gets updated in 
    //          the reservation station, however it may add a cycle delay.
    //          So, transparent.

    rat_to_decode.ps1 = rat_table[decode_to_rat.rs1]; 
    rat_to_decode.ps2 = rat_table[decode_to_rat.rs2];

    // Transparency
    rat_to_decode.ps1_valid = (cdb_to_rat.pd == rat_to_decode.ps1 | cdb_to_rat_2.pd== rat_to_decode.ps1) ? '1 : (~busy[rat_to_decode.ps1]);
    rat_to_decode.ps2_valid = (cdb_to_rat.pd == rat_to_decode.ps2 | cdb_to_rat_2.pd== rat_to_decode.ps2) ? '1 : (~busy[rat_to_decode.ps2]);

end

always_ff @ (posedge clk) begin
    if(rst) begin

        // Reset to make architectural registers map to same physical registers
        for(int i = 0; i < (1 << (RAT_ARCH_REG_IDX + 1)); i++) begin
            rat_table[unsigned'(i)] <= (RAT_PHYS_REG_IDX + 1)'(unsigned'(i));
        end

        // Set all ARCH registers to not busy
        for(int i = 0; i < (1<<(RAT_PHYS_REG_IDX+1)); i++) begin
            busy[unsigned'(i)] <= '0;
        end

    end else if (branch_mispredict) begin
        // Update the rat table to the RRF values
        rat_table <= rrf_to_rat_table;

         // Set all ARCH registers to not busy
        for(int i = 0; i < (1<<(RAT_PHYS_REG_IDX+1)); i++) begin
            busy[unsigned'(i)] <= '0;
        end
    end else begin

        // Update old pd and set as busy
        if(decode_to_rat.rd != '0 && decode_to_rat.write_en) begin
            // ILLEGAL_PD0 : assert(decode_to_rat.pd != '0);
            // WRITE_TO_RD0 : assert(decode_to_rat.rd != '0);
            
            rat_table[decode_to_rat.rd] <= decode_to_rat.pd;

            // This assert may be wrong for the current design
            // MAPPING_RD_TO_BUSY_PD : assert(busy[decode_to_rat.pd] == '0);
            
            busy[decode_to_rat.pd] <= '1;
        end

        // Validate a cdb broadcast
        // if(cdb_to_rat.valid && cdb_to_rat.pd == rat_table[cdb_to_rat.rd]) begin
        if(cdb_to_rat.valid) begin
            busy[cdb_to_rat.pd] <= '0;
        end
        if(cdb_to_rat_2.valid) begin
            busy[cdb_to_rat_2.pd] <= '0;
        end
    
        // CDB_AND_DECODE_REFER_TO_SAME_RD : assert(cdb_to_rat.valid -> (cdb_to_rat.rd != decode_to_rat.rd));
    
    end
end




endmodule
