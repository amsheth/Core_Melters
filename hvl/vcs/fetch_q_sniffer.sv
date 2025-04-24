// Looks at the ROB and reports which instructions are getting resolved by the time they should be committed
// https://stackoverflow.com/questions/67714329/systemverilog-string-variable-as-format-specifier-for-display-write

module fetch_q_sniffer import rv32i_types::*; (input clk, rst);

// (1) File datastructures
// Copying code from https://www.chipverify.com/systemverilog/systemverilog-file-io
int file_fd;

logic queue_rst;
logic enqueue;
logic dequeue;
logic is_queue_full;
logic is_queue_empty;

assign queue_rst = $root.top_tb.dut.fetchQ.rst;
assign enqueue = $root.top_tb.dut.fetchQ.enqueue;
assign dequeue = $root.top_tb.dut.fetchQ.dequeue;
assign is_queue_full = $root.top_tb.dut.fetchQ.is_full;
assign is_queue_empty = $root.top_tb.dut.fetchQ.is_empty;

initial begin
    file_fd = $fopen("../../perf_counter/fetch_q_sniffer.log", "w");
    $fdisplay(file_fd, "queue_rst, enqueue, dequeue, is_queue_full, is_queue_empty");
end

always_ff @ (posedge clk) begin

    if(rst) begin
    end else begin
        $fdisplay(file_fd, "0x%h, 0x%h, 0x%h, 0x%h, 0x%h", 
                    queue_rst, enqueue, dequeue, is_queue_full, is_queue_empty);
    end

end

final begin
    $fflush(file_fd);
    $fclose(file_fd);
end

endmodule;
