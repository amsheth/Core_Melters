module s_queue import rv32i_types::*; #(
                    parameter LENGTH = 4,
                    parameter NUM_CDB = 2
                  )(
                  input logic                       clk, rst,
                  
                  // LSQ <- CDB
                  input cdb_entry_t                 cdb,
                  input cdb_entry_t                 cdb2,
                  
                  // LSQ <-> dispatch
                  input dispatch_to_lsq_t           dispatch_to_lsq,
                  input logic                       dispatch_stall,
                  output logic                      is_lsq_full,

                  // LSQ <-> LSQ adder
                  input  logic                      lsq_dequeue,
                  output lsq_entry_t                lsq_to_adder,

                  // LSQ -> Regfile
                  input logic   [31:0]              ps1_value,
                  output logic [PHYS_REG_IDX : 0]   ps1_s, ps2_s,

                  // SQ <-> LD_RS
                  output dispatch_to_lsq_t          squeue [LENGTH],
                  output logic [$clog2(LENGTH) - 1 : 0] sq_head
                  );

///////////////////////////////
// Logic copied from queue.sv//
///////////////////////////////
cdb_entry_t cdb_array [NUM_CDB];
assign cdb_array[0] = cdb;
assign cdb_array[1] = cdb2;

localparam LENGTHEXP = $clog2(LENGTH);

logic   enqueue;

//logic   dequeue;
    
//logic   is_lsq_full;
logic   is_empty;

dispatch_to_lsq_t queue [LENGTH];
dispatch_to_lsq_t rdata;

logic [LENGTHEXP: 0] head;
logic [LENGTHEXP: 0] tail;

assign sq_head = head[$clog2(LENGTH) - 1 : 0];
assign squeue = queue;

always_comb begin
    is_lsq_full  = ((head % LENGTH) == (tail % LENGTH)) && (head[LENGTHEXP] != tail[LENGTHEXP]);
    is_empty = ((head % LENGTH) == (tail % LENGTH)) && (head[LENGTHEXP] == tail[LENGTHEXP]);
    rdata = queue[head % LENGTH];
end

always_ff @ (posedge clk) begin
    if(rst) begin
        head <= '0;
        tail <= '0;
        for(int i = 0; i < LENGTH; i++) begin
            queue[i] <= '0;
        end
    end else begin
        if(lsq_dequeue) begin
            head <= head + {{(LENGTHEXP){1'b0}}, {1'b1}};
            queue[head % LENGTH] <= '0;
        end
        
        if(enqueue) begin
            queue[tail % LENGTH] <= dispatch_to_lsq;
            if(dispatch_to_lsq.ps1_valid) begin
                queue[tail % LENGTH].imm <= dispatch_to_lsq.imm + ps1_value;
                for(int i = 0; i < NUM_CDB; i++) begin
                    if(cdb_array[i].pd == dispatch_to_lsq.ps1)
                        queue[tail % LENGTH].imm <= dispatch_to_lsq.imm + cdb_array[i].value;
                end
            end 
            queue[tail % LENGTH].valid <= '1;
            tail <= tail + {{(LENGTHEXP){1'b0}}, {1'b1}};
        end
        
        //////////////////////////////
        // End of code from queue.sv//
        //////////////////////////////

        // LSQ <- CDB
        // Go through the queue and validate source registers based on CDB
        for(int j = 0; j < LENGTH; j++) begin
            for(int i = 0; i < NUM_CDB; i++) begin
                if(queue[j].valid && cdb_array[i].pd == queue[j].ps1) begin
                    queue[j].ps1_valid <= '1;
                    queue[j].imm <= queue[j].imm + cdb_array[i].value;
                end
            end

            for(int i = 0; i < NUM_CDB; i++) begin
                if(queue[j].valid && cdb_array[i].pd == queue[j].ps2) begin
                    queue[j].ps2_valid <= '1;
                end
            end
        end

    end
end

// LSQ -> adder
// Loads don't have a rs2 and Stores don't have an rd
assign lsq_to_adder.data    = rdata;
assign lsq_to_adder.valid   = (rdata.opcode == op_b_store) ? 
                                (!is_empty && rdata.ps1_valid && rdata.ps2_valid)
                               :(!is_empty && rdata.ps1_valid);

// LSQ -> Regfile
assign ps1_s = {6{~is_empty}} & rdata.ps1;
assign ps2_s = {6{~is_empty}} & rdata.ps2;

// LSQ <- adder
//assign dequeue = adder_to_lsq.dequeue;

// LSQ <- dispatch
assign enqueue = dispatch_to_lsq.valid && !is_lsq_full && !dispatch_stall;

// LSQ -> dispatch
// assign lsq_to_dispatch.is_full = is_full;

endmodule;
