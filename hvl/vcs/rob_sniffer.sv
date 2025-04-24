// Looks at the ROB and reports which instructions are getting resolved by the time they should be committed
// https://stackoverflow.com/questions/67714329/systemverilog-string-variable-as-format-specifier-for-display-write

module rob_sniffer import rv32i_types::*; (input clk, rst);

// (1) File datastructures
// Copying code from https://www.chipverify.com/systemverilog/systemverilog-file-io
int file_fd;

dispatch_to_ROB_only_data_t head;
rvfi_t head_rvfi;
logic rob_commit;
logic rob_reset;
logic rob_empty;
logic rob_full;
logic rob_mispredict;

assign head = $root.top_tb.dut.rob_to_rrf.rob_entry.dispatch_data;
assign head_rvfi = $root.top_tb.dut.rob_to_rrf.rob_entry.rvfi;
assign rob_commit = $root.top_tb.dut.rob_to_rrf.rob_entry.commit;
assign rob_reset = $root.top_tb.dut.ROB.rst;
assign rob_empty = $root.top_tb.dut.rob_to_rrf.is_rob_empty;
assign rob_full = $root.top_tb.dut.ROB.is_full;
assign rob_mispredict = $root.top_tb.dut.ROB.branch_mispredict;

int num_inst_committed;

initial begin
    file_fd = $fopen("../../perf_counter/rob_sniffer.log", "w");
    $fdisplay(file_fd, "rob_rst, commit, mispred, opcode, pc, pc_next, pc_calc, order, inst, rob_empty, rob_full");
end

always_ff @ (posedge clk) begin

    if(rst) begin
    end else begin
        $fdisplay(file_fd, "0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h", 
                    rob_reset, rob_commit, rob_mispredict, head.opcode, head.pc, 
                    head.pc_next, head.calculated_pc_next, head_rvfi.order, 
                    head_rvfi.inst, rob_empty, rob_full);
    end

end

final begin
    $fflush(file_fd);
    $fclose(file_fd);
end

endmodule;
