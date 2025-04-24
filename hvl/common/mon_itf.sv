interface mon_itf#(
            parameter       CHANNELS = 1
)(
    input   bit             clk,
    input   bit             rst
);

            logic           valid     [CHANNELS];
            logic   [63:0]  order     [CHANNELS];
            logic   [31:0]  inst      [CHANNELS];
            logic           halt      [CHANNELS];
            logic   [4:0]   rs1_addr  [CHANNELS];
            logic   [4:0]   rs2_addr  [CHANNELS];
            logic   [31:0]  rs1_rdata [CHANNELS];
            logic   [31:0]  rs2_rdata [CHANNELS];
            logic   [4:0]   rd_addr   [CHANNELS];
            logic   [31:0]  rd_wdata  [CHANNELS];
            logic   [4:0]   frd_addr  [CHANNELS];
            logic   [31:0]  frd_wdata [CHANNELS];
            logic   [31:0]  pc_rdata  [CHANNELS];
            logic   [31:0]  pc_wdata  [CHANNELS];
            logic   [31:0]  mem_addr  [CHANNELS];
            logic   [3:0]   mem_rmask [CHANNELS];
            logic   [3:0]   mem_wmask [CHANNELS];
            logic   [31:0]  mem_rdata [CHANNELS];
            logic   [31:0]  mem_wdata [CHANNELS];

            bit             error = 1'b0;

endinterface
