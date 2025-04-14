module alu_rs
import rv32i_types::*;
#(
    parameter NUM_RS=1
)(
    input   logic   clk,rst,
    input   dispatch_to_rs_t        dispatch_to_res_station,
    input   cdb_entry_t             cdb,
    input   cdb_entry_t             cdb2,
    input   logic                   alu_is_ready,// alu_is_ready_2,
    input   logic                   stall,
    output  logic                   is_full,
    output  rs_to_alu_t             alu_rs_out
    // output  rs_to_alu_t             alu_rs_out_2
);

ALU_RS_entry_t rs_table      [NUM_RS];
logic   [NUM_RS - 1:0]  rs_ready_to_dispatch; // High when the RS entry is ready to be dispatched

logic   [NUM_RS - 1:0]  rs_entry_is_vacant; // Is high when the RS entry is empty

logic   [$clog2(NUM_RS)-1:0]       RS_loc;  ////change name   
logic   [$clog2(NUM_RS + 1) -1:0]     remove_rs_for_alu;//, remove_rs_for_alu_2;

logic   [NUM_ORDER:0]   order;

priority_enc  #(.COUNT(NUM_RS)) priority_enc(.in(rs_entry_is_vacant),.out(RS_loc));

// Output is RS_full 
assign is_full=(rs_entry_is_vacant == '0); // ? '1 : '0; 

always_comb begin
    for(int i = 0; i < NUM_RS; i++)
        rs_ready_to_dispatch[i] = (rs_table[i].data.ps1_valid & rs_table[i].data.ps2_valid) & (~rs_entry_is_vacant[i]);
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
            if ((~rs_entry_is_vacant[i] & cdb.valid & (rs_table[i].data.ps1 == cdb.pd)& (rs_table[i].data.ps1!='0))|(!rs_entry_is_vacant[i] & cdb2.valid & (rs_table[i].data.ps1 == cdb2.pd)& (rs_table[i].data.ps1!='0))) begin
                rs_table[i].data.ps1_valid<='1;
            end
            if ((~rs_entry_is_vacant[i] & cdb.valid & (rs_table[i].data.ps2 == cdb.pd) & (rs_table[i].data.ps2!='0))|(!rs_entry_is_vacant[i] & cdb2.valid & (rs_table[i].data.ps2 == cdb2.pd) & (rs_table[i].data.ps2!='0))) begin
                rs_table[i].data.ps2_valid<='1;
            end
        end

        if (remove_rs_for_alu != '0) begin
            rs_entry_is_vacant[remove_rs_for_alu-1]<='1;
            rs_table[remove_rs_for_alu-1]<='0;
        end

        // if (remove_rs_for_alu_2 != '0) begin
        //     rs_entry_is_vacant[remove_rs_for_alu_2-1]<='1;
        //     rs_table[remove_rs_for_alu_2-1]<='0;
        // end
    end
end




// For Output Logic
always_comb begin
    remove_rs_for_alu   = '0;

    for (int i=0;i<NUM_RS;i++) begin
        
        // (2) Check if a reservation station is ready to dispatch
        if(rs_ready_to_dispatch[i]) begin
            if(alu_is_ready & (remove_rs_for_alu == '0 | rs_table[i].order < rs_table[remove_rs_for_alu].order))
                    remove_rs_for_alu = ($clog2(NUM_RS + 1))'(unsigned'(i + 1));
        end

    end
end

// always_comb begin
//     remove_rs_for_alu_2 = '0;
//     for (int i=0;i<NUM_RS;i++) begin
        
//         // (2) Check if a reservation station is ready to dispatch
//         if(rs_ready_to_dispatch[i]) begin
//             if(alu_is_ready_2 && ($clog2(NUM_RS + 1))'(unsigned'(i)) > remove_rs_for_alu && (remove_rs_for_alu_2 == '0 || rs_table[i].order < rs_table[remove_rs_for_alu_2[$clog2(NUM_RS)-1:0]].order))
//                     remove_rs_for_alu_2 = ($clog2(NUM_RS + 1))'(unsigned'(i + 1));
//         end

//     end
// end

always_comb begin
    alu_rs_out = ( (remove_rs_for_alu != '0 ) & alu_is_ready) ? rs_table[remove_rs_for_alu - 1].data : 'x;
    alu_rs_out.valid = remove_rs_for_alu != '0 ? '1 : '0;
end

// always_comb begin
//     alu_rs_out_2 = ( (remove_rs_for_alu_2 != '0 ) && alu_is_ready_2) ? rs_table[remove_rs_for_alu_2 - 1].data : 'x;
//     alu_rs_out_2.valid = remove_rs_for_alu_2 != '0 ? '1 : '0;
// end
endmodule
