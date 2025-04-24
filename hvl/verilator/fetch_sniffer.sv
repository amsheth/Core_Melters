module fetch_sniffer import rv32i_types::*; (
    input logic clk, rst
);

logic has_fetched_branch;
logic has_enqueued_branch;
logic has_committed_branch;
logic has_branch_mispredict;
logic has_br_update;
logic has_jals;
logic has_enqueued_jals;
logic has_jalrs;
logic has_jals_commited;
logic has_jalrs_commited;
logic has_enqueued_jalrs;
// logic logic_name = value;
logic has_jal_mispredict;
logic has_jalr_mispredict;
logic has_push;
logic has_pop;
//logic has_defaulted_prediction;

assign has_fetched_branch = ($root.top_tb.dut.fetchy_fetch.ufp_rdata[6:0]==op_b_br) && ($root.top_tb.dut.fetchy_fetch.ufp_resp);
assign has_push = ($root.top_tb.dut.fetchy_fetch.push)&& ($root.top_tb.dut.fetchy_fetch.ufp_resp);
assign has_pop = ($root.top_tb.dut.fetchy_fetch.pop)&& ($root.top_tb.dut.fetchy_fetch.ufp_resp);
assign has_jals = ($root.top_tb.dut.fetchy_fetch.ufp_rdata[6:0]==op_b_jal) && ($root.top_tb.dut.fetchy_fetch.ufp_resp);
assign has_jalrs = ($root.top_tb.dut.fetchy_fetch.ufp_rdata[6:0]==op_b_jalr) && ($root.top_tb.dut.fetchy_fetch.ufp_resp);
assign has_enqueued_branch = ($root.top_tb.dut.ufp_rdata[6:0]==op_b_br) && ($root.top_tb.dut.fetchQ.enqueue);
assign has_enqueued_jals = ($root.top_tb.dut.ufp_rdata[6:0]==op_b_jal) && ($root.top_tb.dut.fetchQ.enqueue);
assign has_enqueued_jalrs = ($root.top_tb.dut.ufp_rdata[6:0]==op_b_jalr) && ($root.top_tb.dut.fetchQ.enqueue);
assign has_committed_branch = ($root.top_tb.dut.monitor_inst[6:0]==op_b_br) && ($root.top_tb.dut.monitor_valid);
assign has_branch_mispredict = $root.top_tb.dut.cpu_rrf.branch_mispredict && $root.top_tb.dut.cpu_rrf.rob_entry.dispatch_data.opcode == op_b_br;
assign has_jalr_mispredict = $root.top_tb.dut.cpu_rrf.branch_mispredict && $root.top_tb.dut.cpu_rrf.rob_entry.dispatch_data.opcode == op_b_jalr;
assign has_jal_mispredict = $root.top_tb.dut.cpu_rrf.branch_mispredict && $root.top_tb.dut.cpu_rrf.rob_entry.dispatch_data.opcode == op_b_jal;
assign has_jals_commited = ($root.top_tb.dut.monitor_inst[6:0]==op_b_jal) && ($root.top_tb.dut.monitor_valid);
assign has_jalrs_commited = ($root.top_tb.dut.monitor_inst[6:0]==op_b_jalr) && ($root.top_tb.dut.monitor_valid);
assign has_br_update = $root.top_tb.dut.fetchy_fetch.br_update;
//assign has_defaulted_prediction = ($root.top_tb.dut.fetchy_fetch.branch_table_state != '0) && has_fetched_branch; 

int num_branch_fetched;
int num_branch_enqueued;
int num_branch_committed;
int num_mispredicts;
int num_jals;
int num_jals_commited;
int num_enqueued_jals;
int num_jals_mispredict;
int num_jalrs;
int num_jalrs_commited;
int num_enqueued_jalrs;
int num_jalrs_mispredict;
int num_has_push;
int num_has_pop;
int num_br_update;
//int num_defaulted_prediction;

always_ff @ (posedge clk) begin
    if(rst) begin
        num_branch_fetched <= 0;
        num_branch_enqueued <= 0;
        num_branch_committed <= 0;
        num_mispredicts <= 0;
        num_br_update <= 0;
        num_jalrs<=0;
        num_jals<=0;
        num_jalrs_commited<=0;
        num_jals_commited<=0;
        num_enqueued_jals<=0;
        num_enqueued_jalrs<=0;
        num_jalrs_mispredict<=0;
        num_jals_mispredict<=0;
        num_has_pop<=0;
        num_has_push<=0;

        //num_defaulted_prediction <= 0;
    end else begin
        num_branch_fetched <= num_branch_fetched + (has_fetched_branch ? 1 : 0);
        num_branch_enqueued <= num_branch_enqueued + (has_enqueued_branch ? 1 : 0);
        num_branch_committed <= num_branch_committed + (has_committed_branch ? 1 : 0);
        num_mispredicts <= num_mispredicts + (has_branch_mispredict ? 1 : 0);
        num_br_update <= num_br_update + (has_br_update ? 1 : 0);
        num_jals <= num_jals + (has_jals ? 1 : 0);
        num_jals_commited<=num_jals_commited+(has_jals_commited?1:0);
        num_enqueued_jals <= num_enqueued_jals + (has_enqueued_jals ? 1 : 0);
        num_jals_mispredict <= num_jals_mispredict + (has_jal_mispredict ? 1 : 0);
        num_jalrs <= num_jalrs + (has_jalrs ? 1 : 0);
        num_jalrs_commited<=num_jalrs_commited+(has_jalrs_commited?1:0);
        num_enqueued_jalrs <= num_enqueued_jalrs + (has_enqueued_jalrs ? 1 : 0);
        num_jalrs_mispredict <= num_jalrs_mispredict + (has_jalr_mispredict ? 1 : 0);
        num_has_push <= num_has_push + (has_push ? 1 : 0);
        num_has_pop <= num_has_pop + (has_pop ? 1 : 0);
        //num_defaulted_prediction <= num_defaulted_prediction + (has_defaulted_prediction ? 1 : 0);
    end
end

final begin
    $display("Fetch Sniffer: Fetched branches : %d", num_branch_fetched);
    $display("Fetch Sniffer: Enqueued branches : %d", num_branch_enqueued);
    $display("Fetch Sniffer: Committed branches : %d", num_branch_committed);
    $display("Fetch Sniffer: Committed branch mispredicts: %d", num_mispredicts);
    $display("Fetch Sniffer: Branch table updates: %d", num_br_update);
    $display("Fetch Sniffer: Branch mispredicts: %d", num_mispredicts);
    $display("Fetch Sniffer: JAL (Fetched/Enqueued/Committed/Mispredict): %d / %d / %d / %d", num_jals, num_enqueued_jals, num_jals_commited, num_jals_mispredict);
    $display("Fetch Sniffer: JALR (Fetched/Enqueued/Committed/Mispredict): %d / %d / %d / %d", num_jalrs, num_enqueued_jalrs, num_jalrs_commited, num_jalrs_mispredict);
    $display("Fetch Sniffer: PUSH: %d", num_has_push);
    $display("Fetch Sniffer: POP: %d", num_has_pop);
    //$display("Fetch Sniffer: Branch predictions Defaulted: %d", num_defaulted_prediction);
    $display("Fetch Sniffer: Committed Branch Predictor Accuracy: %f", real'(num_branch_committed - num_mispredicts) / real'(num_branch_committed));
end

endmodule;
