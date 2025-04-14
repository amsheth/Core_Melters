/*	* module freelist
	* Description: This is a parameterized free list which allows for dequeue and enqueue.
	* Note: Enqueuing when full will irrecoverably invalidate the queue state.
    *       Similarly for dequeuing when empty.
    * EXCEPTION: Enqueuing while dequeing is allowed, even if the queue is full, however
    *            not when the queue is empty
    * Note: Based on queue.sv
*/
module free_list
import rv32i_types::*;
#(
    parameter       WIDTH = PHYS_REG_IDX + 1,
    parameter       LENGTHEXP = PHYS_REG_IDX,
    parameter       AT_RESET_FREE_REG_START_VAL = 32,
    parameter       AT_RESET_FREE_REG_COUNT = 32
)(
    input   clk, rst,

    input   logic   [WIDTH - 1: 0]  wdata,
    input   logic   enqueue,
    input   logic   branch_mispredict,
    output  logic   [WIDTH - 1: 0]  rdata,
    input  logic   dequeue,
    
    output  logic   is_full,
    output  logic   is_empty
);

localparam LENGTH = NUM_ROB_ENTRIES;

logic [WIDTH - 1 : 0] queue [LENGTH];

logic [LENGTHEXP: 0] head;
logic [LENGTHEXP: 0] tail;


always_comb begin
    is_full  = ((head % LENGTH) == (tail % LENGTH)) && (head[LENGTHEXP] != tail[LENGTHEXP]);
    is_empty = ((head % LENGTH) == (tail % LENGTH)) && (head[LENGTHEXP] == tail[LENGTHEXP]);
    rdata = queue[head % LENGTH];
    // FREE_LIST_OUTPUTTING_0 : assert((!is_empty) -> (rdata != '0));

end

always_ff @ (posedge clk) begin
    if(rst) begin
        tail <= (LENGTHEXP + 1)'(unsigned'(AT_RESET_FREE_REG_COUNT));
        head <= '0;
        for(int i = 0; i < LENGTH; i++) begin
            // queue[(LENGTHEXP)'(i)] <= (LENGTHEXP + 1)'(AT_RESET_FREE_REG_START_VAL) + (LENGTHEXP + 1)'(i);
            queue[unsigned'(i)]<=(WIDTH)'(32+unsigned'(i));
        end
    end else begin
        if (branch_mispredict) begin
            tail <= head;
            tail[LENGTHEXP] <=!head[LENGTHEXP];
            if(enqueue) begin
                // enqueue_when_full: assert(!is_full || dequeue);
                queue[tail % LENGTH] <= wdata;
            end
        end else begin
            if(dequeue) begin
                // dequeue_when_empty: assert(!is_empty);
                head <= head + {{(LENGTHEXP){1'b0}}, {1'b1}};
            end
            if(enqueue) begin
                // enqueue_when_full: assert(!is_full || dequeue);
                queue[tail % LENGTH] <= wdata;
                tail <= tail + {{(LENGTHEXP){1'b0}}, {1'b1}};
            end
        end
        
    end
end

endmodule : free_list;
