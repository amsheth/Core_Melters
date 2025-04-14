module res_station
import rv32i_types::*;
#(
    parameter NUM_RS=1
)(
    input   logic   clk,rst,
    input   dispatch_to_rs_t        dispatch_to_res_station,
    input   cdb_entry_t             cdb,
    input   cdb_entry_t             cdb2,
    // input   logic                   br_is_ready,
    input   logic                   mult_is_ready,
    input   logic                   div_is_ready,
    input   logic                   stall,
    output  logic                   is_full,
    // output  rs_to_br_t              br_rs_out,
    output  rs_to_div_t             div_rs_out,
    output  rs_to_mult_t            mult_rs_out
);

MUL_RS_entry_t rs_table      [NUM_RS];
logic   [NUM_RS - 1:0]  rs_ready_to_dispatch; // High when the RS entry is ready to be dispatched

logic   [NUM_RS - 1:0]  rs_entry_is_vacant; // Is high when the RS entry is empty

logic   [$clog2(NUM_RS)-1:0]       RS_loc;  ////change name  
logic   [$clog2(NUM_RS+1) -1:0]     remove_rs_for_div;
logic   [$clog2(NUM_RS+1) -1:0]     remove_rs_for_mult;
 
logic   [NUM_ORDER:0]   order;

priority_enc  #(.COUNT(NUM_RS)) priority_enc(.in(rs_entry_is_vacant),.out(RS_loc));

// Output is RS_full 
assign is_full= (rs_entry_is_vacant == '0); // ? '1 : '0; 

always_comb begin
    for(int i = 0; i < NUM_RS; i++)
        rs_ready_to_dispatch[unsigned'(i)] = (rs_table[unsigned'(i)].data.ps1_valid & rs_table[unsigned'(i)].data.ps2_valid) & (~rs_entry_is_vacant[unsigned'(i)]);
end
// For Input Logic
always_ff @( posedge clk ) begin
    if(rst) begin
        for(int i = 0; i < NUM_RS; i++) begin
            // rs_table[i] <= '0;
            order<='0;
            rs_entry_is_vacant[i] <= '1;
        end
    end
    else begin
        if (dispatch_to_res_station.valid & ~(is_full) & ~(stall)) begin
            rs_table[RS_loc].data<=dispatch_to_res_station;
            rs_table[RS_loc].order<=order;
            order<=order + 1'b1;
            rs_entry_is_vacant[RS_loc]<='0;
        end

        for (int i=0;i<NUM_RS;i++)begin
            if ((~rs_entry_is_vacant[i] & cdb.valid & (rs_table[i].data.ps1 == cdb.pd) & (rs_table[i].data.ps1!='0))|(!rs_entry_is_vacant[i] & cdb2.valid & (rs_table[i].data.ps1 == cdb2.pd) & (rs_table[i].data.ps1!='0))) begin
                rs_table[i].data.ps1_valid<='1;
            end
            if ((~rs_entry_is_vacant[i] & cdb.valid & (rs_table[i].data.ps2 == cdb.pd) & (rs_table[i].data.ps2!='0))|(!rs_entry_is_vacant[i] & cdb2.valid & (rs_table[i].data.ps2 == cdb2.pd) & (rs_table[i].data.ps2!='0))) begin
                rs_table[i].data.ps2_valid<='1;
            end
        end

        if (remove_rs_for_div != '0) begin
            rs_entry_is_vacant[remove_rs_for_div-1]<='1;
            rs_table[remove_rs_for_div-1]<='0;
        end

        if (remove_rs_for_mult != '0) begin
            rs_entry_is_vacant[remove_rs_for_mult-1]<='1;
            rs_table[remove_rs_for_mult-1]<='0;
        end
    end
end




// For Output Logic
always_comb begin
    remove_rs_for_div   = '0;
    remove_rs_for_mult  = '0;

    // (1) Go through each reservation station
    for (int i=0;i<NUM_RS;i++) begin
        
        // (2) Check if a reservation station is ready to dispatch
        if(rs_ready_to_dispatch[unsigned'(i)]) begin

            // (3) Check the opcode of the reservation station and dispatch appropriately
            // if (rs_table[i].opcode == op_b_reg) begin

            //     // if funct7[0] == 1 then RS is a mult/div/rem instruction
            //     if(rs_table[i].funct7[0]) begin

                    // if funct3[2] == 1 then RS is a div/rem instruction
                if(rs_table[unsigned'(i)].data.funct3[2]) begin
                    if(div_is_ready & (remove_rs_for_div == '0 | rs_table[unsigned'(i)].order < rs_table[remove_rs_for_div].order))
                        remove_rs_for_div = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
                end else begin
                    if(mult_is_ready & (remove_rs_for_mult == '0 | rs_table[i].order < rs_table[remove_rs_for_mult].order))
                        remove_rs_for_mult = ($clog2(NUM_RS + 1))'(unsigned'(i + 1));
                //     end
                // // if funct7[0] == 0 then RS is a ALU instruction
                // end 
            end
        end

    end
end

assign mult_rs_out = ( (remove_rs_for_mult != '0 ) & mult_is_ready) ? rs_table[remove_rs_for_mult - 1].data : '0;
assign div_rs_out = ( (remove_rs_for_div != '0 ) & div_is_ready) ? rs_table[remove_rs_for_div - 1].data : '0;
// assign br_rs_out = ( (remove_rs_for_br != '0 ) && br_is_ready) ? rs_table[remove_rs_for_br - 1] : '0;

endmodule
