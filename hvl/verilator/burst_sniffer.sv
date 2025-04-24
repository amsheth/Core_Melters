// Looks at the ROB and reports which instructions are getting resolved by the time they should be committed
// https://stackoverflow.com/questions/67714329/systemverilog-string-variable-as-format-specifier-for-display-write

module burst_sniffer import rv32i_types::*; (input clk, rst);

// (1) File datastructures
// Copying code from https://www.chipverify.com/systemverilog/systemverilog-file-io
int file_fd;

logic burst_controller_rst;
logic icache_req, icache_req_reg, dcache_req;
logic icache_resp, dcache_resp;
int miss_times;
int count_of_icache_req;


assign burst_controller_rst = $root.top_tb.dut.burst_ctrl.rst;
assign icache_req = $root.top_tb.dut.dfp_read;
assign dcache_req = $root.top_tb.dut.dfp_dread | $root.top_tb.dut.dfp_dwrite;
assign icache_resp = $root.top_tb.dut.dfp_resp;
assign dcache_resp = $root.top_tb.dut.dfp_dresp;
assign miss_times = $root.top_tb.dut.burst_ctrl.miss_times;

initial begin
    file_fd = $fopen("../../perf_counter/burst_sniffer.log", "w");
    $fdisplay(file_fd, "rst, i_req, d_req, i_rsp, d_rsp");
end

always_ff @( posedge clk ) begin : blockName
    if (rst)
        count_of_icache_req<='0;
    else begin
    icache_req_reg<=icache_req;
    if (icache_req_reg && !icache_req)
        count_of_icache_req<=count_of_icache_req+1'b1;
    end
end


always_ff @ (posedge clk) begin

    if(rst) begin
    end else begin
        $fdisplay(file_fd, "0x%h, 0x%h, 0x%h, 0x%h, 0x%h",
                    burst_controller_rst, icache_req, dcache_req, icache_resp, dcache_resp);
    end

end

final begin
    $display("BURST Sniffer: No of times requested : %d", count_of_icache_req);
    $display("BURST Sniffer: No of times missed : %d", miss_times);
    $display("BURST Sniffer: perc of times missed : %d", miss_times/count_of_icache_req);
    $fflush(file_fd);
    $fclose(file_fd);
end

endmodule;
