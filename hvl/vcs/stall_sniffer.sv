module stall_sniffer import rv32i_types::*; (input clk, rst);

// (1) File datastructures
// Copying code from https://www.chipverify.com/systemverilog/systemverilog-file-io
int file_fd;

logic rs_is_full, br_rs_is_full, alu_rs_is_full, sq_is_full, ld_rs_is_full;
logic both_alu_queue_is_full, br_queue_is_full, div_queue_is_full, mult_queue_is_full;
logic mult_busy, div_busy;
logic free_list_is_empty, is_fetch_q_empty;
logic rob_is_full;
logic dispatch_stall;

assign rs_is_full = $root.top_tb.dut.rs_is_full;
assign br_rs_is_full = $root.top_tb.dut.br_rs_is_full;
assign alu_rs_is_full = $root.top_tb.dut.alu_rs_is_full;
assign sq_is_full = $root.top_tb.dut.st_q_is_full; // SQ ready to dispatch to CDB
assign ld_rs_is_full = $root.top_tb.dut.ld_rs_is_full; // LD ready to dispatch to CDB
// assign both_alu_queue_is_full = $root.top_tb.dut.FU_ready [0] && $root.top_tb.dut.FU_ready_2 [2]; // Both ALU queue ready to dispatch to CDB
assign both_alu_queue_is_full ='0;
assign br_queue_is_full = $root.top_tb.dut.FU_ready_2[1]; // BR queue ready to dispatch to CDB
assign div_queue_is_full = $root.top_tb.dut.FU_ready[2]; // DIV queue ready to dispatch to CDB
assign mult_queue_is_full = $root.top_tb.dut.FU_ready[1]; // MULT queue ready to dispatch to CDB
assign mult_busy = ~$root.top_tb.dut.mult_is_ready;
assign div_busy = ~$root.top_tb.dut.div_is_ready;
assign free_list_is_empty = $root.top_tb.dut.free_list_is_empty;
assign is_fetch_q_empty = $root.top_tb.dut.is_fetch_q_empty;
assign rob_is_full = $root.top_tb.dut.ROB.is_full;
assign dispatch_stall = $root.top_tb.dut.dispatch_stall;

initial begin
    file_fd = $fopen("../../perf_counter/stall_sniffer.log", "w");
    $fdisplay(file_fd, "rst, rs_full, br_rs_full, alu_rs_full, sq_is_full, ld_rs_is_full, both_alu_queue_full, br_queue_full, div_queue_full, mult_queue_full, mult_busy, div_busy, free_list_empty, fetch_q_empty, rob_full, dispatch_stall, stall");
    $fdisplay(file_fd, "rst, rs, brrs, alrs, sq, ld_rs, b_aluq, brq, divq, multq, mulbu, divbu, fr_l_em, f_q_emp, rob, disp_stall");

end

always_ff @ (posedge clk) begin

    if(rst) begin
    end else begin
        $fdisplay(file_fd, "0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h, 0x%h",
                    rst, rs_is_full, br_rs_is_full, alu_rs_is_full, sq_is_full, ld_rs_is_full, both_alu_queue_is_full, br_queue_is_full,
                    div_queue_is_full, mult_queue_is_full, mult_busy, div_busy, free_list_is_empty, is_fetch_q_empty, 
                    rob_is_full, dispatch_stall);
    end

end

final begin
    $fflush(file_fd);
    $fclose(file_fd);
end

endmodule;
