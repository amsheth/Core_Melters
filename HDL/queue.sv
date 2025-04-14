/*	* module queue
	* Description: This is a parameterized queue which allows for dequeue and enqueue.
	* Note: Enqueuing when full will irrecoverably invalidate the queue state.
    *       Similarly for dequeuing when empty.
    * EXCEPTION: Enqueuing while dequeing is allowed, even if the queue is full, however
    *            not when the queue is empty
*/
module queue import rv32i_types::*; #(
    parameter       WIDTH = 32,
    parameter       LENGTHEXP = 0
)(
    input   clk, rst,

    input   logic   [WIDTH - 1: 0]  wdata,
    input   logic   enqueue,

    output  logic   [WIDTH - 1: 0]  rdata,
    input  logic   dequeue,
    
    output  logic   is_full,
    output  logic   is_empty
);

localparam LENGTH = 1 << LENGTHEXP;

logic [WIDTH - 1 : 0] queue [LENGTH];

logic [LENGTHEXP: 0] head;
logic [LENGTHEXP: 0] tail;

always_comb begin
    is_full  = ((head % LENGTH) == (tail % LENGTH)) & (head[LENGTHEXP] != tail[LENGTHEXP]);
    is_empty = ((head % LENGTH) == (tail % LENGTH)) & (head[LENGTHEXP] == tail[LENGTHEXP]);
    rdata = queue[head % LENGTH];
end

always_ff @ (posedge clk) begin
    if(rst) begin
        head <= '0;
        tail <= '0;
    end else begin
        if(dequeue) begin
            // dequeue_when_empty: assert(!is_empty);
            head <= head + 1'b1;
        end
        
        if(enqueue) begin
            // enqueue_when_full: assert(!is_full || dequeue);
            queue[tail % LENGTH] <= wdata;
            tail <= tail + 1'b1;
        end 
    end
end

endmodule : queue;

// FAQ:
// #1) Where should I put the test case for the queue?
//          -> In a seperate file
// #2) Should we use the sv 2015(I forget the exact name of the manual) reference manual? Like how to use assert, etc.
//          -> The ca uses google
// #3) Is the queue transparent? I.E. Does an enqueue and a dequeue at the same time on an empty queue have to dequeue the enqueued value?
//          -> This queue is not transparent. So, if enqueue is raised, then the rdata will avaliable for reading on the next cycle -- assuming the queue is empty.
// #4) Should we take a queue depth of 0 into account?
//          -> Nope, the queue depth should be a power of 2
// #5) How to handle multiple execution units wanting to write to the same cdb?
//    -> make the CPU have multiple CDB or have arbiter
