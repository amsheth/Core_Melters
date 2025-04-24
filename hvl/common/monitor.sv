module monitor #(
    parameter CHANNELS = 1
)(
    mon_itf itf
);

    logic [CHANNELS*1 -1:0] rvfi_valid;
    logic [CHANNELS*64-1:0] rvfi_order;
    logic [CHANNELS*32-1:0] rvfi_insn;
    logic [CHANNELS*1 -1:0] rvfi_trap;
    logic [CHANNELS*1 -1:0] rvfi_halt;
    logic [CHANNELS*1 -1:0] rvfi_intr;
    logic [CHANNELS*2 -1:0] rvfi_mode;
    logic [CHANNELS*5 -1:0] rvfi_rs1_addr;
    logic [CHANNELS*5 -1:0] rvfi_rs2_addr;
    logic [CHANNELS*32-1:0] rvfi_rs1_rdata;
    logic [CHANNELS*32-1:0] rvfi_rs2_rdata;
    logic [CHANNELS*5 -1:0] rvfi_rd_addr;
    logic [CHANNELS*32-1:0] rvfi_rd_wdata;
    logic [CHANNELS*32-1:0] rvfi_pc_rdata;
    logic [CHANNELS*32-1:0] rvfi_pc_wdata;
    logic [CHANNELS*32-1:0] rvfi_mem_addr;
    logic [CHANNELS*4 -1:0] rvfi_mem_rmask;
    logic [CHANNELS*4 -1:0] rvfi_mem_wmask;
    logic [CHANNELS*32-1:0] rvfi_mem_rdata;
    logic [CHANNELS*32-1:0] rvfi_mem_wdata;
    logic [CHANNELS*1 -1:0] rvfi_mem_extamo;

    assign rvfi_trap = '0;
    assign rvfi_intr = '0;
    assign rvfi_mode = '0;
    assign rvfi_mem_extamo = '0;
    generate for (genvar channel = 0; channel < CHANNELS; channel++) begin : assign_channels
        assign rvfi_valid    [channel*1  +: 1 ] =   itf.valid    [channel];
        assign rvfi_order    [channel*64 +: 64] =   itf.order    [channel];
        assign rvfi_insn     [channel*32 +: 32] =   itf.inst     [channel];
        assign rvfi_halt     [channel*1  +: 1 ] =   itf.halt     [channel];
        assign rvfi_rs1_addr [channel*5  +: 5 ] =   itf.rs1_addr [channel];
        assign rvfi_rs2_addr [channel*5  +: 5 ] =   itf.rs2_addr [channel];
        assign rvfi_rs1_rdata[channel*32 +: 32] = (|itf.rs1_addr [channel]) ? itf.rs1_rdata[channel] : '0;
        assign rvfi_rs2_rdata[channel*32 +: 32] = (|itf.rs2_addr [channel]) ? itf.rs2_rdata[channel] : '0;
        assign rvfi_rd_addr  [channel*5  +: 5 ] =   itf.rd_addr  [channel];
        assign rvfi_rd_wdata [channel*32 +: 32] = (|itf.rd_addr  [channel]) ? itf.rd_wdata[channel] : '0;
        assign rvfi_pc_rdata [channel*32 +: 32] =   itf.pc_rdata [channel];
        assign rvfi_pc_wdata [channel*32 +: 32] =   itf.pc_wdata [channel];
        assign rvfi_mem_addr [channel*32 +: 32] = { itf.mem_addr [channel][31:2], 2'b00};
        assign rvfi_mem_rmask[channel*4  +: 4 ] =   itf.mem_rmask[channel];
        assign rvfi_mem_wmask[channel*4  +: 4 ] =   itf.mem_wmask[channel];
        assign rvfi_mem_rdata[channel*32 +: 32] =   itf.mem_rdata[channel];
        assign rvfi_mem_wdata[channel*32 +: 32] =   itf.mem_wdata[channel];
    end endgenerate

    initial begin
        for (int unsigned channel = 0; channel < CHANNELS; channel++) begin
            itf.halt[channel] = '0;
        end
    end

    function bit is_halt(input logic [31:0] inst);
        is_halt = (inst === 32'h00000063) || (inst === 32'h0000006f) || (inst === 32'hF0002013);
    endfunction

    always @(posedge itf.clk iff !itf.rst) begin
        for (int unsigned channel = 0; channel < CHANNELS; channel++) begin
            if (itf.valid[channel] && is_halt(itf.inst[channel])) begin
                itf.halt[channel] <= 1'b1;
            end
        end
    end

    int time_fd;
    initial time_fd = $fopen("./time.txt", "w");

    longint inst_count = longint'(0);
    longint cycle_count = longint'(0);
    longint start_time = longint'(0);
    bit ipc_printed = 1'b0;

    longint power_start_time = longint'(0);
    bit power_printed = 1'b0;

    always @(posedge itf.clk iff !itf.rst) begin
        cycle_count += longint'(1);
        for (int unsigned channel = 0; channel < CHANNELS; channel++) begin
            if (itf.valid[channel]) begin
                inst_count += longint'(1);
                if (itf.inst[channel] == 32'h00102013) begin
                    $display("Monitor: Segment Start time is %t", $time);
                    inst_count = longint'(0);
                    cycle_count = longint'(0);
                    start_time = $time;
                end
                if (itf.inst[channel] == 32'h00202013) begin
                    ipc_printed = 1'b1;
                    $display("Monitor: Segment Stop time is %t", $time);
                    $display("Monitor: Segment IPC: %f", real'(inst_count) / cycle_count);
                    $display("Monitor: Segment Time: %t", $time - start_time);
                end
                if (itf.inst[channel] == 32'h00302013) begin
                    $display("Monitor: Power Start time is %t", $time);
                    power_start_time = $time;
                    if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
                        `ifdef ECE411_VER_DUMP
                            $dumpon();
                        `else
                            $fsdbDumpon();
                        `endif
                    end
                end
                if (itf.inst[channel] == 32'h00402013) begin
                    power_printed = 1'b1;
                    $display("Monitor: Power Stop time is %t", $time);
                    $fwrite(time_fd, "%0t\n", power_start_time);
                    $fwrite(time_fd, "%0t", $time);
                    if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
                        `ifdef ECE411_VER_DUMP
                            $dumpoff();
                        `else
                            $fsdbDumpoff();
                        `endif
                    end
                end
            end
        end
    end

    final begin
        if (!ipc_printed) begin
            $display("Monitor: Total IPC: %f", real'(inst_count) / cycle_count);
            $display("Monitor: Total Time: %t", $time - start_time);
        end
        if (!power_printed) begin
            $fwrite(time_fd, "%0t\n", power_start_time);
            $fwrite(time_fd, "%0t", $time);
        end
        $fclose(time_fd);
    end

    `ifndef ECE411_NO_SPIKE

        int spike_fd;
        initial spike_fd = $fopen("../spike/commit.log", "w");
        final $fclose(spike_fd);

        always @ (posedge itf.clk iff !itf.rst) begin
            for (int unsigned channel = 0; channel < CHANNELS; channel++) begin
                if(itf.valid[channel]) begin
                    if (itf.order[channel] % 1000 == 0) begin
                        $display("dut commit No.%d, rd_s: x%02d, rd: 0x%h", itf.order[channel], itf.rd_addr[channel], |itf.rd_addr[channel] ? itf.rd_wdata[channel] : 32'd0);
                    end
                    if (itf.inst[channel][1:0] == 2'b11) begin
                        $fwrite(spike_fd, "core   0: 3 0x%h (0x%h)", itf.pc_rdata[channel], itf.inst[channel]);
                    end else begin
                        $fwrite(spike_fd, "core   0: 3 0x%h (0x%h)", itf.pc_rdata[channel], itf.inst[channel][15:0]);
                    end
                    if (itf.rd_addr[channel] != 0) begin
                        if (itf.rd_addr[channel] < 10)
                            $fwrite(spike_fd, " x%0d  ", itf.rd_addr[channel]);
                        else
                            $fwrite(spike_fd, " x%0d ", itf.rd_addr[channel]);
                        $fwrite(spike_fd, "0x%h", itf.rd_wdata[channel]);
                    end
                    if (itf.frd_addr[channel] != 0) begin
                        if (itf.frd_addr[channel] < 10)
                            $fwrite(spike_fd, " f%0d  ", itf.frd_addr[channel]);
                        else
                            $fwrite(spike_fd, " f%0d ", itf.frd_addr[channel]);
                        $fwrite(spike_fd, "0x%h", itf.frd_wdata[channel]);
                    end
                    if (itf.mem_rmask[channel] != 0) begin
                        automatic int first_1 = 0;
                        for(int i = 0; i < 4; i++) begin
                            if(itf.mem_rmask[channel][i]) begin
                                first_1 = i;
                                break;
                            end
                        end
                        $fwrite(spike_fd, " mem 0x%h", {itf.mem_addr[channel][31:2], 2'b0} + first_1);
                    end
                    if (itf.mem_wmask[channel] != 0) begin
                        automatic int amount_o_1 = 0;
                        automatic int first_1 = 0;
                        for(int i = 0; i < 4; i++) begin
                            if(itf.mem_wmask[channel][i]) begin
                                amount_o_1 += 1;
                            end
                        end
                        for(int i = 0; i < 4; i++) begin
                            if(itf.mem_wmask[channel][i]) begin
                                first_1 = i;
                                break;
                            end
                        end
                        $fwrite(spike_fd, " mem 0x%h", {itf.mem_addr[channel][31:2], 2'b0} + first_1);
                        case (amount_o_1)
                            1: begin
                                automatic logic[7:0] wdata_byte = itf.mem_wdata[channel][8*first_1 +: 8];
                                $fwrite(spike_fd, " 0x%h", wdata_byte);
                            end
                            2: begin
                                automatic logic[15:0] wdata_half = itf.mem_wdata[channel][8*first_1 +: 16];
                                $fwrite(spike_fd, " 0x%h", wdata_half);
                            end
                            4:
                                $fwrite(spike_fd, " 0x%h", itf.mem_wdata[channel]);
                        endcase
                    end
                    $fwrite(spike_fd, "\n");
                    if (is_halt(itf.inst[channel])) begin
                        break;
                    end
                end
            end
        end

    `endif

    `ifndef ECE411_NO_X_CHECK

        always @(posedge itf.clk iff !itf.rst) begin
            for (int unsigned channel = 0; channel < CHANNELS; channel++) begin
                if ($isunknown(itf.valid[channel])) begin
                    $error("RVFI Interface Error: valid is 1'bx");
                    itf.error <= 1'b1;
                end
            end
        end

        generate for (genvar channel = 0; channel < CHANNELS; channel++) begin : x_detection
            always @(posedge itf.clk iff (!itf.rst && itf.valid[channel])) begin
                if ($isunknown(itf.order[channel])) begin
                    $error("RVFI Interface Error: order contains 'x");
                    itf.error <= 1'b1;
                end
                if ($isunknown(itf.inst[channel])) begin
                    $error("RVFI Interface Error: inst contains 'x");
                    itf.error <= 1'b1;
                end
                if ($isunknown(itf.rs1_addr[channel])) begin
                    $error("RVFI Interface Error: rs1_addr contains 'x");
                    itf.error <= 1'b1;
                end
                if ($isunknown(itf.rs2_addr[channel])) begin
                    $error("RVFI Interface Error: rs2_addr contains 'x");
                    itf.error <= 1'b1;
                end
                if (itf.rs1_addr[channel] != '0) begin
                    if ($isunknown(itf.rs1_rdata[channel])) begin
                        $error("RVFI Interface Error: rs1_rdata contains 'x");
                        itf.error <= 1'b1;
                    end
                end
                if (itf.rs2_addr[channel] != '0) begin
                    if ($isunknown(itf.rs2_rdata[channel])) begin
                        $error("RVFI Interface Error: rs2_rdata contains 'x");
                        itf.error <= 1'b1;
                    end
                end
                if ($isunknown(itf.rd_addr[channel])) begin
                    $error("RVFI Interface Error: rd_addr contains 'x");
                    itf.error <= 1'b1;
                end
                if (|itf.rd_addr[channel]) begin
                    if ($isunknown(itf.rd_wdata[channel])) begin
                        $error("RVFI Interface Error: rd_wdata contains 'x");
                        itf.error <= 1'b1;
                    end
                end
                if ($isunknown(itf.pc_rdata[channel])) begin
                    $error("RVFI Interface Error: pc_rdata contains 'x");
                    itf.error <= 1'b1;
                end
                if ($isunknown(itf.pc_wdata[channel])) begin
                    $error("RVFI Interface Error: pc_wdata contains 'x");
                    itf.error <= 1'b1;
                end
                if ($isunknown(itf.mem_rmask[channel])) begin
                    $error("RVFI Interface Error: mem_rmask contains 'x");
                    itf.error <= 1'b1;
                end
                if ($isunknown(itf.mem_wmask[channel])) begin
                    $error("RVFI Interface Error: mem_wmask contains 'x");
                    itf.error <= 1'b1;
                end
                if (|itf.mem_rmask[channel] || |itf.mem_wmask[channel]) begin
                    if ($isunknown(itf.mem_addr[channel])) begin
                        $error("RVFI Interface Error: mem_addr contains 'x");
                        itf.error <= 1'b1;
                    end
                end
                if (|itf.mem_rmask[channel]) begin
                    for (int i = 0; i < 4; i++) begin
                        if (itf.mem_rmask[channel][i]) begin
                            if ($isunknown(itf.mem_rdata[channel][i*8 +: 8])) begin
                                $error("RVFI Interface Error: mem_rdata contains 'x");
                                itf.error <= 1'b1;
                            end
                        end
                    end
                end
                if (|itf.mem_wmask[channel]) begin
                    for (int i = 0; i < 4; i++) begin
                        if (itf.mem_wmask[channel][i]) begin
                            if ($isunknown(itf.mem_wdata[channel][i*8 +: 8])) begin
                                $error("RVFI Interface Error: mem_wdata contains 'x");
                                itf.error <= 1'b1;
                            end
                        end
                    end
                end
            end
        end endgenerate

    `endif

    `ifndef ECE411_NO_RVFI

        logic [15:0] errcode;

        riscv_formal_monitor_rv32imc monitor(
            .clock              (itf.clk),
            .reset              (itf.rst),
            .rvfi_valid         (rvfi_valid),
            .rvfi_order         (rvfi_order),
            .rvfi_insn          (rvfi_insn),
            .rvfi_trap          (rvfi_trap),
            .rvfi_halt          (rvfi_halt),
            .rvfi_intr          (rvfi_intr),
            .rvfi_mode          (rvfi_mode),
            .rvfi_rs1_addr      (rvfi_rs1_addr),
            .rvfi_rs2_addr      (rvfi_rs2_addr),
            .rvfi_rs1_rdata     (rvfi_rs1_rdata),
            .rvfi_rs2_rdata     (rvfi_rs2_rdata),
            .rvfi_rd_addr       (rvfi_rd_addr),
            .rvfi_rd_wdata      (rvfi_rd_wdata),
            .rvfi_pc_rdata      (rvfi_pc_rdata),
            .rvfi_pc_wdata      (rvfi_pc_wdata),
            .rvfi_mem_addr      (rvfi_mem_addr),
            .rvfi_mem_rmask     (rvfi_mem_rmask),
            .rvfi_mem_wmask     (rvfi_mem_wmask),
            .rvfi_mem_rdata     (rvfi_mem_rdata),
            .rvfi_mem_wdata     (rvfi_mem_wdata),
            .rvfi_mem_extamo    (rvfi_mem_extamo),
            .errcode            (errcode)
        );

        always @(posedge itf.clk) begin
            if (errcode != 0) begin
                $error("RVFI Monitor Error");
                itf.error <= 1'b1;
            end
        end

    `endif

endmodule
