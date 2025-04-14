module RRF
import rv32i_types::*;
#(
    parameter P_REG_IDX_NUM_BITS = PHYS_REG_IDX,
    parameter NUM_RRF_ENTRIES = NUM_ARCH_REG
)
(
    input clk,
    input rst,
    input ROB_to_RRF_t rob_to_rrf,
    output logic [P_REG_IDX_NUM_BITS:0] free_p_reg,
    output logic free_list_enqueue,
    output RRF_to_ROB_t rrf_to_rob,
    output logic [P_REG_IDX_NUM_BITS:0] rrf_to_rat_table [NUM_RRF_ENTRIES], // Send RRF values to RAT on reset
    output logic branch_mispredict,
    output logic store_commited,
    output logic [31:0] new_fetch_pc, // Calculated PC value is sent to the fetch stage
    output logic [63:0] new_fetch_order, // Order of the instruction is sent to the fetch stage
    logic [BRANCH_PRED_M - 1:0] br_update_hist
);

ROB_entry_t rob_entry; 

assign rob_entry = rob_to_rrf.rob_entry;

logic commit_not_flush;
// assign commit_not_flush = rob_entry.commit && !rob_entry.flush && !rob_to_rrf.is_rob_empty;
assign commit_not_flush = rob_entry.commit && !rob_to_rrf.is_rob_empty && rob_entry.dispatch_data.rd != '0;

// logic new_signal;
// assign new_signal = rob_entry.commit && !rob_to_rrf.is_rob_empty;

// Send the dequeue if there is a valid entry to dequeue and we do not have a branch mispredict
//assign rrf_to_rob.dequeue = (free_list_enqueue && ~branch_mispredict) || (rob_entry.dispatch_data.rd =='0 
//                            && !rob_to_rrf.is_rob_empty && (rob_entry.commit == 1'b1));
//assign rrf_to_rob.dequeue = !free_list_is_full ;

logic [P_REG_IDX_NUM_BITS:0] p_reg[NUM_RRF_ENTRIES];

// The value that will be freed is the old p_reg in the entry that was just modified
//assign free_p_reg = p_reg[rob_entry.dispatch_data.rd]/*The value that is in the RAT at rd*/;
//assign free_list_enqueue = ((rob_entry.dispatch_data.rd != '0) & (~rob_to_rrf.is_rob_empty) & (rob_entry.commit == 1'b1)) ? '1 : '0;



// Store commited goes high if we have a valid instruction with a store opcode, tells the lsq_adder when to store
//assign store_commited = commit_not_flush && (rob_entry.dispatch_data.opcode == op_b_store); //& rob_entry.commit;

// (1) RRF Output During Mispredict -- Used on op_b_br, op_b_jal, op_b_jalr
// assign branch_mispredict = commit_not_flush & (rob_entry.dispatch_data.pc_next != rob_entry.dispatch_data.calculated_pc_next);
logic is_br_opcode;
assign is_br_opcode = rob_entry.dispatch_data.opcode inside {op_b_br, op_b_jalr};
assign branch_mispredict = ~rob_to_rrf.is_rob_empty & is_br_opcode & rob_entry.commit 
                            & (rob_entry.dispatch_data.pc_next != rob_entry.dispatch_data.calculated_pc_next);
                            
assign br_update_hist = rob_entry.dispatch_data.br_hist;



assign new_fetch_pc = rob_entry.dispatch_data.calculated_pc_next;
assign new_fetch_order = rob_entry.dispatch_data.order;

always_comb begin
    rrf_to_rat_table = p_reg;
    if(commit_not_flush)
        rrf_to_rat_table[rob_entry.dispatch_data.rd] = rob_entry.dispatch_data.pd;
end

// always_comb begin
//     free_p_reg = 'x;
//     free_list_enqueue = '0;
//     if ( commit_not_flush ) begin
//                 if() begin
//                     free_p_reg = p_reg[rob_entry.dispatch_data.rd];
//                     free_list_enqueue = '1;
//                 end
//     end
// end
assign free_list_enqueue = (commit_not_flush & rob_to_rrf.rob_entry.dispatch_data.opcode != op_b_store & rob_to_rrf.rob_entry.dispatch_data.opcode != op_b_br);
assign free_p_reg        = free_list_enqueue ? p_reg[rob_entry.dispatch_data.rd] : 'x;
assign store_commited = rob_to_rrf.rob_entry.dispatch_data.opcode == op_b_store & ~rob_to_rrf.rob_entry.commit;
assign rrf_to_rob.dequeue = rob_to_rrf.rob_entry.commit & ~rob_to_rrf.is_rob_empty;
// (3) Write into the RRF & send data to RVFI
always_ff @ (posedge clk) begin
    if(rst) begin
        for(int i = 0; i < NUM_RRF_ENTRIES; i++) begin
            p_reg[unsigned'(i)] <= (P_REG_IDX_NUM_BITS + 1)'(unsigned'(i));
        end
    end else begin
        if (commit_not_flush) begin
            // Check the value that we want to update isn't r0
                // Update the incoming rd value in the RRF with the incoming physical register
                p_reg[rob_entry.dispatch_data.rd] <= rob_entry.dispatch_data.pd;
        end
    end
end

endmodule
