module rob import rv32i_types::*; #(
    parameter       ROB_LENGTH_EXP = $clog2(NUM_ROB_ENTRIES)
)(
    input   clk, rst,
    
    input   dispatch_to_ROB_t       dispatch_to_rob,    // done
    input   RRF_to_ROB_t            rrf_to_rob,         // done
    input   cdb_entry_t             cdb,                // done
    input   cdb_entry_t             cdb2,
    input   logic                   stall,
    input   logic                   branch_mispredict,

    output  ROB_to_dispatch_t       rob_to_dispatch,    // done
    output  ROB_to_RRF_t            rob_to_rrf          // done
);

logic enqueue;
logic dequeue;
ROB_entry_t wdata;
ROB_entry_t rdata;
logic is_full;
logic is_empty;


assign enqueue = dispatch_to_rob.enqueue_rob & ~stall;
assign dequeue = rrf_to_rob.dequeue;
assign wdata.dispatch_data = dispatch_to_rob.dispatch_to_ROB_only_data;
assign wdata.rvfi = dispatch_to_rob.rvfi;
assign wdata.commit = '0;
assign rob_to_dispatch.is_rob_full = is_full;
assign rob_to_rrf.is_rob_empty = is_empty;


localparam LENGTH = 1 << ROB_LENGTH_EXP;
localparam LENGTHEXP = ROB_LENGTH_EXP;

ROB_entry_t queue [LENGTH];

logic [LENGTHEXP: 0] head;
logic [LENGTHEXP: 0] tail;
logic [LENGTHEXP: 0] tail_reg;

assign rob_to_dispatch.rob_entry_idx = tail[LENGTHEXP - 1 : 0];

always_comb begin
    is_full  = ((head % LENGTH) == (tail % LENGTH)) & (head[LENGTHEXP] != tail[LENGTHEXP]);
    is_empty = ((head % LENGTH) == (tail % LENGTH)) & (head[LENGTHEXP] == tail[LENGTHEXP]);

    rob_to_rrf.rob_entry = queue[head % LENGTH];
    rob_to_rrf.rob_entry.rvfi.valid = rob_to_rrf.rob_entry.rvfi.valid & ~is_empty;
    rob_to_rrf.rob_entry.commit = ~is_empty & rob_to_rrf.rob_entry.commit;
end

always_ff @ (posedge clk) begin
    if(cdb.valid == 1'b1) begin
        // CDB_BROADCASTING_ALREADY_VALIDATED_ROB_ENTRY : assert(queue[cdb.rob_entry_idx].commit == '0);
        queue[cdb.rob_entry_idx].commit         <= 1'b1;
        queue[cdb.rob_entry_idx].rvfi.rs1_rdata <= cdb.rs1_value;
        queue[cdb.rob_entry_idx].rvfi.rs2_rdata <= cdb.rs2_value;
        queue[cdb.rob_entry_idx].rvfi.rd_wdata  <= cdb.value;
        queue[cdb.rob_entry_idx].rvfi.valid     <= '1;
        queue[cdb.rob_entry_idx].rvfi.pc_wdata  <= cdb.calculated_pc_next;
        queue[cdb.rob_entry_idx].dispatch_data.calculated_pc_next <= cdb.calculated_pc_next;    
        queue[cdb.rob_entry_idx].rvfi.mem_addr  <= cdb.mem_addr;
        queue[cdb.rob_entry_idx].rvfi.mem_rmask <= cdb.mem_rmask;
        queue[cdb.rob_entry_idx].rvfi.mem_wmask <= cdb.mem_wmask;
        queue[cdb.rob_entry_idx].rvfi.mem_rdata <= cdb.mem_rdata;
        queue[cdb.rob_entry_idx].rvfi.mem_wdata <= cdb.mem_wdata;
    end
    if(cdb2.valid == 1'b1) begin
        // CDB_BROADCASTING_ALREADY_VALIDATED_ROB_ENTRY : assert(queue[cdb2.rob_entry_idx].commit == '0);
        queue[cdb2.rob_entry_idx].commit         <= 1'b1;
        queue[cdb2.rob_entry_idx].rvfi.rs1_rdata <= cdb2.rs1_value;
        queue[cdb2.rob_entry_idx].rvfi.rs2_rdata <= cdb2.rs2_value;
        queue[cdb2.rob_entry_idx].rvfi.rd_wdata  <= cdb2.value;
        queue[cdb2.rob_entry_idx].rvfi.valid     <= '1;
        queue[cdb2.rob_entry_idx].rvfi.pc_wdata  <= cdb2.calculated_pc_next;
        queue[cdb2.rob_entry_idx].dispatch_data.calculated_pc_next <= cdb2.calculated_pc_next;    
        queue[cdb2.rob_entry_idx].rvfi.mem_addr  <= cdb2.mem_addr;
        queue[cdb2.rob_entry_idx].rvfi.mem_rmask <= cdb2.mem_rmask;
        queue[cdb2.rob_entry_idx].rvfi.mem_wmask <= cdb2.mem_wmask;
        queue[cdb2.rob_entry_idx].rvfi.mem_rdata <= cdb2.mem_rdata;
        queue[cdb2.rob_entry_idx].rvfi.mem_wdata <= cdb2.mem_wdata;
    end
    if(rst| branch_mispredict) begin
        /* TODO: do we need to set all the valid bits to 0 for branch mispredict*/
        head <= '0;
        tail <= '0;
        // for(int i = 0; i < LENGTH; i++) begin
        //     queue[i].flush <= '0;
        // end
    end
    else begin
        if(dequeue) begin
            queue[head % LENGTH].rvfi.valid <= '0;
            // queue[head % LENGTH].flush <= '0;
            head <= head + 1'b1;
        end
        
        if(enqueue) begin
            queue[tail % LENGTH] <= wdata;
            queue[tail % LENGTH].commit <= 1'b0;
            // queue[tail % LENGTH].flush <= 1'b0;
            tail <= tail + 1'b1;
        end 
    end
end

endmodule : rob;
