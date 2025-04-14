/**
 * module cpu
 * 
 * cpu -> ins_cache -> burst_controller
 * cpu PC starts at 1eceb000
 * Initialize cache module
 * Check if the cache has the value at the PC
 * If not, request the value from the burst_controller
 * burst_controller will request the value from the memory (wait on cache_resp)
 */

module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr, // Requested address
    output  logic               bmem_read, // Requested read signal
    output  logic               bmem_write, // Requested write signal
    output  logic   [63:0]      bmem_wdata, // Requested data to be written
    input   logic               bmem_ready, // memory ready signal

    input   logic   [31:0]      bmem_raddr, // incoming data's address TODO: need to add logic to burst controller
    input   logic   [63:0]      bmem_rdata, // incoming data
    input   logic               bmem_rvalid // incoming data's valid signal
);

// Ignore Values
logic bmem_ready_trash; assign bmem_ready_trash = bmem_ready;
logic [31:0] bmem_raddr_trash; assign bmem_raddr_trash = bmem_raddr;

// Values received from cache and sent to burst_controller
logic [31:0]    dfp_addr,       dfp_daddr;
logic           dfp_read,       dfp_dread;
logic           dfp_write,      dfp_dwrite;
logic [255:0]   dfp_wdata,      dfp_dwdata;

// D-cache output values
logic [31:0] ufp_drdata;
logic ufp_dresp;


// Values received from burst_controller and sent to cache
logic [255:0] dfp_rdata, dfp_drdata;
logic dfp_resp, dfp_dresp;

// Values reeceived from cache and sent to fetch stage of CPU
logic [31:0] ufp_rdata;
logic ufp_resp;

// Values from the instruction queue
logic [31:0] ufp_addr;
logic [3:0] ufp_rmask;
logic br_en_reg;

// logic [31:0] decode_ins;
logic is_fetch_q_full, is_fetch_q_empty;
logic [159 + BRANCH_PRED_M:0] decode_ins;


// Value from fetch to decode
logic [31:0] pc_fetch, pc_next_fetch;
logic [63:0] order_reg;
logic [BRANCH_PRED_M - 1:0] br_hist_out;

// Decode output values
logic dequeue_ins_queue; // This will be inputted to the instruction queue
logic dequeue_free_list; // This will be inputted to the free list
decode_rename_to_RAT_t decode_to_RAT;
decode_rename_to_dispatch_t decode_to_dispatch_reg, decode_to_dispatch_next;

// Outputs from the free list
logic free_list_is_empty, free_list_is_full;
logic [5:0] free_list_next_p_reg;

// Outputs from the RAT
RAT_to_decode_rename_t rat_to_decode;

// Outputs from the dispatch module
// logic enqueue_rob;
dispatch_to_ROB_t dispatch_to_rob;
dispatch_to_rs_t dispatch_to_rs;
dispatch_to_rs_t dispatch_to_alu;
dispatch_to_rs_t dispatch_to_br;
dispatch_to_lsq_t dispatch_to_ld_rs;
dispatch_to_lsq_t dispatch_to_st_q;
logic dispatch_stall;

// Outputs from the reservation station
logic rs_is_full;
logic alu_rs_is_full;
logic br_rs_is_full;

// Output from the reservation station
rs_to_alu_t decode_to_res_station;
rs_to_alu_t     alu_rs_out, alu_rs_out_2;
rs_to_mult_t    mult_rs_out;
rs_to_div_t     div_rs_out;
rs_to_br_t      br_rs_out;

// Outputs from the lsq_queue
logic ld_rs_is_full, st_q_is_full;
lsq_entry_t ld_rs_to_adder, st_q_to_adder;
dispatch_to_lsq_t        st_q_queue [ST_Q_ENTRIES];
logic [$clog2(ST_Q_ENTRIES) - 1 : 0] sq_head;

// Outputs from the regfile
logic [31:0] ps_value [(2 * 7) - 1]; // Minus one due to odd number of ports 
logic [5:0] ps_select [(2 * 7) - 1]; // Minus one due to odd number of ports
logic [31:0] pd_value [2];
logic [5:0] pd_select [2];
logic       regf_we   [2];

// Outputs from the ALU
cdb_entry_t alu_output_cdb;
logic alu_queue_is_full, alu_is_ready;
cdb_entry_t alu_output_cdb_2;
logic alu_queue_is_full_2, alu_is_ready_2;

// Outputs from the multiplier
logic mult_is_ready;

// Outputs from the divider
logic div_is_ready;

// Outputs from the branch unit
logic br_is_ready;

// Outputs from the arbitrator
cdb_entry_t     cdb_value   [3]; 
logic           FU_ready    [3]; 
logic                       [3 - 1:0]    cdb_arb_select; 

cdb_entry_t     cdb_value_2   [2]; 
logic           FU_ready_2    [2]; 
logic                       [2 - 1:0]    cdb_arb_select_2;

// Outputs from the ROB
ROB_to_dispatch_t rob_to_dispatch;
ROB_to_RRF_t rob_to_rrf;

// Outputs from the RRF
logic [PHYS_REG_IDX:0] rrf_freed_p_reg;
logic rrf_free_list_enqueue;
RRF_to_ROB_t rrf_to_rob;
logic [PHYS_REG_IDX:0] rrf_to_rat_table [NUM_ARCH_REG];
logic branch_mispredict;
logic jal_predict;
logic store_commited;
logic [31:0] new_fetch_pc;
logic [63:0] new_fetch_order;
logic br_update;
logic br_taken;
logic [31:0] br_pc;
logic [BRANCH_PRED_M - 1:0] br_update_hist;

// Outputs from the CDB arbiter
cdb_entry_t cdb_arb_output;

cdb_entry_t cdb_arb_output_2;

// Output from the lsq adder
logic ld_rs_dequeue, st_q_dequeue;
logic [31:0] ufp_daddr, ufp_wdata;
logic [3:0] ufp_drmask, ufp_dwmask;
logic [31:0] ufp_dwdata;

// int c;
// always_ff @( posedge clk ) begin : blockName
//     if (rst)
//         c<=0;
//     else if (branch_mispredict)
//         c<=c+1;
// end


    queue #(.WIDTH(160+BRANCH_PRED_M), .LENGTHEXP(2)) fetchQ (
    .clk(clk),
    .rst(rst | branch_mispredict),
    .wdata({br_hist_out,order_reg,pc_next_fetch, pc_fetch, ufp_rdata}), //  Combine PC next, PC, and instruction
    .enqueue(ufp_resp && !is_fetch_q_full && !br_en_reg), // TODO: account for branch mispredict
    .rdata(decode_ins),
    .dequeue(dequeue_ins_queue), // Input from the decode stage
    .is_full(is_fetch_q_full),
    .is_empty(is_fetch_q_empty));

fetchyfetch fetchy_fetch(
    .clk(clk),
    .rst(rst),
    .ufp_resp(ufp_resp), // Get response signal from cache
    .is_fetch_q_full(is_fetch_q_full),
    .ufp_rdata(ufp_rdata), // Get read data from cache,
    .order_reg(order_reg), // Order of the instruction
    .branch_mispredict(branch_mispredict), // Input from the RRF that the branch was mis-predicted
    .br_update_hist,
    .new_fetch_pc(new_fetch_pc), // The calculated PC received from RRF
    .new_fetch_order(new_fetch_order), // The order of the instruction received from RRF
    .ufp_addr(ufp_addr), // Send address from fetch to cache
    .pc(pc_fetch), // Send PC from fetch to decode
    .pc_n(pc_next_fetch), // Send next PC from fetch to decode
    .ufp_rmask(ufp_rmask), // Send read mask from fetch to cache
    .br_en_reg,
    .br_update,
    .br_taken,
    .br_pc,
    .br_hist_out
);

// Free list
free_list freelist (
    .clk(clk),
    .rst(rst),
    .wdata(rrf_freed_p_reg), // From the RRF
    .enqueue(rrf_free_list_enqueue), // From the RRF
    .rdata(free_list_next_p_reg), // Next available physical register from the free list
    .dequeue(dequeue_free_list),
    .is_empty(free_list_is_empty),
    .is_full(free_list_is_full),
    .branch_mispredict(branch_mispredict)
);
    

decode_rename insdecode (
    .decode_ins(decode_ins),
    .is_ins_queue_empty(is_fetch_q_empty),
    .stall(dispatch_stall),
    .free_list_next_p_reg(free_list_next_p_reg), // Input the next available physical register from free list
    .rat_to_decode(rat_to_decode), // Requested from the RAT after decoding instruction
    .dequeue_ins_queue(dequeue_ins_queue), // Signal dequeue to the instruction queue
    .dequeue_free_list(dequeue_free_list), // Signal dequeue to the free list
    .decode_to_RAT(decode_to_RAT), // Output to the RAT (we want RAT to respond to this request)
    .decode_to_dispatch(decode_to_dispatch_next) // Output to the dispatch module
);

RAT rat (
    .clk(clk),
    .rst(rst),
    .decode_to_rat(decode_to_RAT),
    .cdb_to_rat(cdb_arb_output),
    .cdb_to_rat_2(cdb_arb_output_2),
    .branch_mispredict(branch_mispredict),
    .rrf_to_rat_table(rrf_to_rat_table),
    .rat_to_decode(rat_to_decode)
);

// Sequential block between the decode_rename and dispatch modules
// always_ff @(posedge clk) begin
//     if (rst) begin
//         decode_to_dispatch_reg <= '0;
//     end else begin
//         decode_to_dispatch_reg <= decode_to_dispatch_next;
//     end
// end

assign decode_to_dispatch_reg = decode_to_dispatch_next;


dispatch insdispatch(
    .decode_to_dispatch(decode_to_dispatch_reg),
    .rob_to_dispatch(rob_to_dispatch),
    .rs_is_full(rs_is_full),
    .alu_rs_is_full(alu_rs_is_full),
    .br_rs_is_full(br_rs_is_full),
    .ld_rs_is_full(ld_rs_is_full),
    .st_q_is_full(st_q_is_full),
    .freelist_is_empty(free_list_is_empty),
    .fetch_q_empty(is_fetch_q_empty),
    .dispatch_to_rob(dispatch_to_rob),
    .dispatch_to_rs(dispatch_to_rs),
    .dispatch_to_alu(dispatch_to_alu),
    .dispatch_to_br(dispatch_to_br),
    .dispatch_to_ld_rs(dispatch_to_ld_rs),
    .dispatch_to_st_q(dispatch_to_st_q),
    .dispatch_stall(dispatch_stall)
);


alu_rs #(.NUM_RS(3)) alu_reservation_station(
    .clk(clk),
    .rst(rst|branch_mispredict),
    .dispatch_to_res_station(dispatch_to_alu),
    .alu_is_ready(alu_is_ready || cdb_arb_select [0]),
    // .alu_is_ready_2(alu_is_ready_2 || cdb_arb_select_2 [2]),
    .cdb(cdb_arb_output),
    .cdb2(cdb_arb_output_2),
    .stall(dispatch_stall),
    .is_full(alu_rs_is_full),
    .alu_rs_out(alu_rs_out)
    // .alu_rs_out_2(alu_rs_out_2)
);

res_station #(.NUM_RS(NUM_RS_ENTRIES)) reservation_station(
    .clk(clk),
    .rst(rst|branch_mispredict),
    .dispatch_to_res_station(dispatch_to_rs),
    // .alu_is_ready(alu_is_ready),
    // .br_is_ready(br_is_ready),
    .mult_is_ready(mult_is_ready),
    .div_is_ready(div_is_ready),
    .cdb(cdb_arb_output),
    .cdb2(cdb_arb_output_2),
    .stall(dispatch_stall),
    .is_full(rs_is_full),
    // .alu_rs_out(alu_rs_out),
    // .br_rs_out(br_rs_out),
    .mult_rs_out(mult_rs_out),
    .div_rs_out(div_rs_out)
);

br_rs #(.NUM_RS(3)) br_reservation_station(
    .clk(clk),
    .rst(rst|branch_mispredict),
    .dispatch_to_res_station(dispatch_to_br),
    .br_is_ready(br_is_ready),
    .cdb(cdb_arb_output),
    .cdb2(cdb_arb_output_2),
    .stall(dispatch_stall),
    .is_full(br_rs_is_full),
    .br_rs_out(br_rs_out)
);

s_queue #(.LENGTH(ST_Q_ENTRIES)) s_q (
    // input logic                       
    .clk(clk), 
    .rst(rst|branch_mispredict),
    .cdb(cdb_arb_output),
    .cdb2(cdb_arb_output_2),
    .dispatch_to_lsq(dispatch_to_st_q),
    .dispatch_stall(dispatch_stall||is_fetch_q_empty),
    .is_lsq_full(st_q_is_full),
    .lsq_dequeue(st_q_dequeue), // From the lsq_adder
    .lsq_to_adder(st_q_to_adder),
    .ps1_value(ps_value[10]),
    .ps1_s(ps_select[8]),
    .ps2_s(ps_select[9]),
    .squeue(st_q_queue),
    .sq_head(sq_head)
);

ld_rs #(.LENGTH(LD_RS_ENTRIES), .SQ_LENGTH(ST_Q_ENTRIES))ld_rs(
    .clk(clk), 
    .rst(rst|branch_mispredict),
    // LSQ <- CDB
    .cdb(cdb_arb_output),
    .cdb2(cdb_arb_output_2),
    // LSQ <-> dispatch
    .dispatch_to_lsq(dispatch_to_ld_rs),
    .dispatch_stall(dispatch_stall||is_fetch_q_empty),
    .is_lsq_full(ld_rs_is_full),
    // LSQ <-> LSQ adder
    .lsq_dequeue(ld_rs_dequeue), // From the lsq_adder
    .sq_dequeued(st_q_dequeue),
    .lsq_to_adder(ld_rs_to_adder),
    // LSQ -> Regfile
    .ps1_s(ps_select[12]),
    .ps1_value(ps_value[11]),
    .squeue(st_q_queue),
    .sq_head(sq_head)
);

assign ps_select[0] = alu_rs_out.ps1;
assign ps_select[1] = alu_rs_out.ps2;
assign ps_select[2] = mult_rs_out.ps1;
assign ps_select[3] = mult_rs_out.ps2;
assign ps_select[4] = div_rs_out.ps1;
assign ps_select[5] = div_rs_out.ps2;
assign ps_select[6] = br_rs_out.ps1;
assign ps_select[7] = br_rs_out.ps2;
// ps_select[8] used by store queue
// ps_select[9] used by store queue
// assign ps_select[10] = alu_rs_out_2.ps1;
// assign ps_select[11] = alu_rs_out_2.ps2; 
// ps_select[12] used by load store reservation station
assign ps_select[10] = dispatch_to_st_q.ps1;
assign ps_select[11] = dispatch_to_ld_rs.ps1;

assign pd_select[0] = cdb_arb_output.pd;
assign pd_value[0]  = cdb_arb_output.value;
assign regf_we[0]   = cdb_arb_output.valid;


assign pd_select[1] = cdb_arb_output_2.pd;
assign pd_value[1]  = cdb_arb_output_2.value;
assign regf_we[1]   = cdb_arb_output_2.valid;


transparent_regfile #(
    .NUM_WRITE_PORT(2),
    .NUM_READ_PORT(13),
    .COUNT(NUM_PHYS_REG)
) cpu_regfile (
    /*input   logic                           */    .clk(clk),
    // /*input   logic                           */    .rst(rst),

    /*input   logic                           */    .w_enb(regf_we),        /*[NUM_WRITE_PORT]*/
    /*input   logic   [SELECT_WIDTH - 1:0]    */    .w_sel(pd_select),      /*[NUM_WRITE_PORT]*/
    /*input   logic   [DATA_WIDTH - 1:0]      */    .w_val(pd_value),       /*[NUM_WRITE_PORT]*/ 

    /*input   logic   [SELECT_WIDTH - 1:0]    */    .r_sel(ps_select),      /*[NUM_READ_PORT]*/ 
    /*output  logic   [DATA_WIDTH - 1:0]      */    .r_val(ps_value)        /*[NUM_READ_PORT] */
);


alu_exec #(.NUM_UNITS(1)) alu (
    .rs_to_alu(alu_rs_out),
    .ps1_value(ps_value[0]),
    .ps2_value(ps_value[1]),
    .alu_to_queue_cdb_entry(alu_output_cdb)
);

alu_queue #(.NUM_UNITS(1)) alu_to_cdb_queue(
    .clk(clk),
    .rst(rst|branch_mispredict),
    .cdb_entry_from_alu(alu_output_cdb),
    .cdb_arb_dequeue(cdb_arb_select [0]), // TODO: fix the indexing
    .res_station_select(alu_rs_out.valid), // TODO: Set this properly // did the reservation station select this FU
    .alu_queue_result(cdb_value [0]),
    .alu_queue_is_full(FU_ready [0]),
    .alu_is_ready(alu_is_ready)
);


//mult
multiplier_exec multiplier(
    // Like alu_exec
    /*input   rs_to_mult_t */   .rs_to_mult(mult_rs_out),
    /*input   logic [31: 0]*/   .ps1_value(ps_value[2]),
    /*input   logic [31: 0]*/   .ps2_value(ps_value[3]),

    // Like alu_queue
    /*input   logic      */     .clk(clk), .rst(rst|branch_mispredict),
    /*input   logic      */     .cdb_arb_dequeue                (cdb_arb_select [1]),          // CDB Arbiter has picked this signal
    /*output  cdb_entry_t*/     .mult_queue_result              (cdb_value      [1]),
    /*output  logic      */     .mult_queue_is_full_to_CDB      (FU_ready       [1]),      // Signal sent to CDB Arbiter
    /*output  logic      */     .mult_is_ready_to_RS            (mult_is_ready)            // Signal sent to RS arbiter
);

divider_exec div(
    // Like alu_exec
    /*input   rs_to_div_t  */   .rs_to_div(div_rs_out),
    /*input   logic [31: 0]*/   .ps1_value(ps_value[4]),
    /*input   logic [31: 0]*/   .ps2_value(ps_value[5]),

    // Like alu_queue
    /*input   logic       */    .clk(clk), .rst(rst|branch_mispredict),
    /*input   logic       */    .cdb_arb_dequeue                (cdb_arb_select [2]),          // CDB Arbiter has picked this signal
    /*input   logic       */    .res_station_select_from_RS     (div_rs_out.valid),       // Signal coming from RS arbiter
    /*output  cdb_entry_t */    .div_queue_result               (cdb_value      [2]),
    /*output  logic       */    .div_queue_is_full_to_CDB       (FU_ready       [2]),      // Signal sent to CDB Arbiter
    /*output  logic       */    .div_is_ready_to_RS             (div_is_ready)            // Signal sent to RS arbiter
);

br_exec br (
    .clk(clk),
    .rst(rst|branch_mispredict),
    .ps1_value(ps_value[6]),
    .ps2_value(ps_value[7]),
    .rs_to_br(br_rs_out),
    .res_station_select(br_rs_out.valid),
    .cdb_arb_dequeue(cdb_arb_select_2[1]),
    .br_queue_result(cdb_value_2[1]),
    .br_queue_is_full(FU_ready_2[1]),
    .br_is_ready(br_is_ready),
    .br_update,
    .br_taken,
    .br_pc
);


lsq_adder lsq_adder_module(
    .clk(clk), 
    .rst(rst), 
    .stall('0), // TODO: need to change this
    .store_allowed(store_commited), // RRF signals if it gets a store to commit
    .branch_mispredict(branch_mispredict),
    
    // adder <-> ld and st structs
    .from_st_q(st_q_to_adder),
    .from_ld_rs(ld_rs_to_adder),
    .st_q_dequeue(st_q_dequeue),
    .ld_rs_dequeue(ld_rs_dequeue),

    // adder <- register file
    /*input   logic [31:0]*/     
    .ps1_s_q_value(ps_value[8]),
    .ps2_s_q_value(ps_value[9]),
    .ps1_ld_q_value(ps_value[12]),
    
    // adder <-> D-Cache
    /*output   logic   [31:0]*/  .ufp_addr(ufp_daddr),
    /*output   logic   [3:0] */  .ufp_rmask(ufp_drmask),
    /*output   logic   [3:0] */  .ufp_wmask(ufp_dwmask),
    /*input    logic   [31:0]*/  .ufp_rdata(ufp_drdata),
    /*output   logic   [31:0]*/  .ufp_wdata(ufp_dwdata),
    /*input    logic         */  .ufp_resp(ufp_dresp),

    // adder <-> CDB Arbiter
    /*input   logic      */      .cdb_arb_dequeue(cdb_arb_select_2 [0]),
    /*output  cdb_entry_t*/      .to_cdb_arb(cdb_value_2 [0]),
    /*output  logic      */      .is_full(FU_ready_2 [0])
);

cdb_arb #(.NUM_FU(3)) arbiter(
    // .clk(clk),
    // .rst(rst|branch_mispredict),
    .cdb_value(cdb_value),
    .FU_ready(FU_ready),
    .branch_mispredict(branch_mispredict),
    .select(cdb_arb_select),
    .cdb_arb_output(cdb_arb_output)
);

cdb_arb #(.NUM_FU(2)) arbiter_2(
    // .clk(clk),
    // .rst(rst|branch_mispredict),
    .cdb_value(cdb_value_2),
    .FU_ready(FU_ready_2),
    .branch_mispredict(branch_mispredict),
    .select(cdb_arb_select_2),
    .cdb_arb_output(cdb_arb_output_2)
);

// Instanitation of the RoB
rob ROB (
    .clk(clk),
    .rst(rst),
    .stall(dispatch_stall),
    .dispatch_to_rob(dispatch_to_rob),
    .rrf_to_rob(rrf_to_rob),
    .cdb(cdb_arb_output),
    .cdb2(cdb_arb_output_2),
    .branch_mispredict(branch_mispredict),
    .rob_to_dispatch(rob_to_dispatch),
    .rob_to_rrf(rob_to_rrf)
);

// Instantiation of the RRF
RRF cpu_rrf (
    .clk(clk),
    .rst(rst),
    .rob_to_rrf(rob_to_rrf), // From the ROB, the entry to be committed
    .free_p_reg(rrf_freed_p_reg), // Output the physical register that will be freed
    .free_list_enqueue(rrf_free_list_enqueue), // Signal enqueue the freed physical register
    .rrf_to_rob(rrf_to_rob), // Struct containing dequeue signal to the ROB,
    .rrf_to_rat_table(rrf_to_rat_table), // send the RRF values to the RAT if there is a mispredict
    .branch_mispredict(branch_mispredict), // If there is a branch mispredict
    // .jal_predict,
    .store_commited(store_commited), // If there is a store being committed
    .new_fetch_pc(new_fetch_pc), // PC to send to the fetch stage
    .new_fetch_order(new_fetch_order), // Order of the instruction to send to the fetch stage
    .br_update_hist
);

/**
 * Instruction memory cache
 */
icache ins_cache(
    .clk(clk),
    .rst(rst),
    .ufp_addr(ufp_addr), // From fetch stage of CPU, input
    .ufp_rmask(ufp_rmask), // From fetch stage to make sure its not always one
    .ufp_wmask(4'b0000), // I-cache doesn't write?
    .ufp_rdata(ufp_rdata), // To fetch stage of CPU
    .ufp_wdata('0), // From CPU -- we don't write to I-cache
    .ufp_resp(ufp_resp), // To CPU
    .dfp_addr(dfp_addr), // To burst_controller
    .dfp_read(dfp_read), // To burst_controller
    .dfp_write(dfp_write), // To burst_controller
    .dfp_rdata(dfp_rdata), // From burst_controller
    .dfp_wdata(dfp_wdata), // To burst_controller
    .dfp_resp(dfp_resp) // From burst_controller
);

// /**
//  * Data memory cache
//  */
cache data_cache(
    .clk(clk),
    .rst(rst),
    .ufp_addr(ufp_daddr), // From LSQ
    .ufp_rmask(ufp_drmask), // From LSQ
    .ufp_wmask(ufp_dwmask), // From LSQ
    .ufp_rdata(ufp_drdata), // To the LSQ
    .ufp_wdata(ufp_dwdata), // From the LSQ
    .ufp_resp   (ufp_dresp), // To the LSQ
    .dfp_addr(dfp_daddr), // To burst_controller
    .dfp_read(dfp_dread), // To burst_controller
    .dfp_write(dfp_dwrite), // To burst_controller
    .dfp_rdata(dfp_drdata), // From burst_controller
    .dfp_wdata(dfp_dwdata), // To burst_controller
    .dfp_resp(dfp_dresp) // From burst_controller
);

/**
 * Burst controller
 */
bmem_controller burst_ctrl(
    .clk(clk),
    .rst(rst),
    .bmem_rvalid(bmem_rvalid), // Incoming read valid from memory
    .bmem_addr(bmem_addr), // Address sent to memory (sent from queue to memory)
    .bmem_read(bmem_read), // Read signal sent to memory
    .bmem_write(bmem_write), // Write signal sent to memory
    .bmem_wdata(bmem_wdata), // Data sent to memory to be written
    .bmem_rdata(bmem_rdata), // Data received from memory
    .bmem_ready(bmem_ready),
    .bmem_raddr(bmem_raddr), // TODO Address received from memory (sent from memory -- address corresponding to resp)
    .icache_addr(dfp_addr), // Address received from cache (added to the queue)
    .icache_read(dfp_read), // Read signal received from cache
    .icache_write(dfp_write), // Write signal received from cache
    .icache_rdata(dfp_rdata), // Data sent to cache
    .icache_wdata(dfp_wdata), // Data received from cache
    .icache_resp(dfp_resp), // Response sent to cache

    .dcache_addr(dfp_daddr), // Address received from d-cache
    .dcache_read(dfp_dread), // dfp_read received from d-cache
    .dcache_write(dfp_dwrite), // dfp_write received from d-cache
    .dcache_rdata(dfp_drdata), // Read data from the burst controller to the dfp
    .dcache_wdata(dfp_dwdata), // data to write from d-cache
    .dcache_resp(dfp_dresp) // response signal from the burst controller to the dfp
);


// burst_controller burst_ctrl(
//     .clk(clk),
//     .rst(rst),
//     .mem_rvalid(bmem_rvalid), // Incoming read valid from memory
//     .mem_addr(bmem_addr), // Address sent to memory (sent from queue to memory)
//     .mem_read(bmem_read), // Read signal sent to memory
//     .mem_write(bmem_write), // Write signal sent to memory
//     .mem_wdata(bmem_wdata), // Data sent to memory to be written
//     .mem_rdata(bmem_rdata), // Data received from memory
//     .mem_ready(bmem_ready),
//     // .mem_raddr(bmem_raddr), // TODO Address received from memory (sent from memory -- address corresponding to resp)
//     .icache_addr(dfp_addr), // Address received from cache (added to the queue)
//     .icache_read(dfp_read), // Read signal received from cache
//     .icache_write(dfp_write), // Write signal received from cache
//     .icache_rdata(dfp_rdata), // Data sent to cache
//     .icache_wdata(dfp_wdata), // Data received from cache
//     .icache_resp(dfp_resp), // Response sent to cache

//     .dcache_addr(dfp_daddr), // Address received from d-cache
//     .dcache_read(dfp_dread), // dfp_read received from d-cache
//     .dcache_write(dfp_dwrite), // dfp_write received from d-cache
//     .dcache_rdata(dfp_drdata), // Read data from the burst controller to the dfp
//     .dcache_wdata(dfp_dwdata), // data to write from d-cache
//     .dcache_resp(dfp_dresp) // response signal from the burst controller to the dfp
// );


// RVFI STRUCT
bit           monitor_valid;
logic   [63:0]  monitor_order;
logic   [31:0]  monitor_inst;
logic   [4:0]   monitor_rs1_addr;
logic   [4:0]   monitor_rs2_addr;
logic   [31:0]  monitor_rs1_rdata;
logic   [31:0]  monitor_rs2_rdata;
logic   [4:0]   monitor_rd_addr;
logic   [31:0]  monitor_rd_wdata;
logic   [31:0]  monitor_pc_rdata;
logic   [31:0]  monitor_pc_wdata;
logic   [31:0]  monitor_mem_addr;
logic   [3:0]   monitor_mem_rmask;
logic   [3:0]   monitor_mem_wmask;
logic   [31:0]  monitor_mem_rdata;
logic   [31:0]  monitor_mem_wdata;

assign monitor_valid     = rob_to_rrf.rob_entry.rvfi.valid;
assign monitor_order     = rob_to_rrf.rob_entry.rvfi.order;
assign monitor_inst      = rob_to_rrf.rob_entry.rvfi.inst;
assign monitor_rs1_addr  = rob_to_rrf.rob_entry.rvfi.rs1_addr;
assign monitor_rs2_addr  = rob_to_rrf.rob_entry.rvfi.rs2_addr;
assign monitor_rs1_rdata = rob_to_rrf.rob_entry.rvfi.rs1_rdata;
assign monitor_rs2_rdata = rob_to_rrf.rob_entry.rvfi.rs2_rdata;
assign monitor_rd_addr   = rob_to_rrf.rob_entry.rvfi.rd_addr;
assign monitor_rd_wdata  = rob_to_rrf.rob_entry.rvfi.rd_wdata;
assign monitor_pc_rdata  = rob_to_rrf.rob_entry.rvfi.pc_rdata;
assign monitor_pc_wdata  = rob_to_rrf.rob_entry.rvfi.pc_wdata;
assign monitor_mem_addr  = rob_to_rrf.rob_entry.rvfi.mem_addr;
assign monitor_mem_rmask = rob_to_rrf.rob_entry.rvfi.mem_rmask;
assign monitor_mem_wmask = rob_to_rrf.rob_entry.rvfi.mem_wmask;
assign monitor_mem_rdata = rob_to_rrf.rob_entry.rvfi.mem_rdata;
assign monitor_mem_wdata = rob_to_rrf.rob_entry.rvfi.mem_wdata;


endmodule : cpu;
