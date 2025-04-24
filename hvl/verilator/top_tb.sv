module top_tb
(
    input   logic   clk,
    input   logic   rst
);

    longint timeout;
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    rob_sniffer rob_sniff_module(.*);
    fetch_q_sniffer fetch_q_sniff_module(.*);
    fetch_sniffer fetch_sniffer_module(.*);
    burst_sniffer burst_sniff_module(.*);
    stall_sniffer stall_sniff_module(.*);
    ls_sniffer ls_sniff_module(.*);


    `include "rvfi_reference.svh"

    initial begin
        `ifdef ECE411_FST_DUMP
            $dumpfile("dump.fst");
        `endif
        `ifdef ECE411_VCD_DUMP
            $dumpfile("dump.vcd");
        `endif
        $dumpvars();
        if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
            $dumpvars(0, dut);
            $dumpoff();
        end else begin
            $dumpvars();
        end
    end

    final begin
        $dumpflush;
    end

    always @(posedge clk) begin
        for (int unsigned i = 0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mon_itf.error != 0) begin
            $fatal;
        end
        if (mem_itf.error != 0) begin
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule
