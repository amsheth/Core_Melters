module fetchyfetch_dual_port
import rv32i_types::*;
(
    input logic clk,
    input logic rst,
    input logic ufp_resp,
    input logic is_fetch_q_full,
    input logic branch_mispredict,
    input logic [63:0] new_fetch_order,
    input logic [31:0] new_fetch_pc,
    
    input logic br_update,
    input logic br_taken,
    input logic [31:0] br_pc,

    input  logic [31:0]   ufp_rdata,
    output logic [31:0] ufp_addr,
    output logic [31:0] pc,
    output logic [31:0] pc_n,
    output logic [3:0] ufp_rmask,
    output logic [63:0] order_reg,
    output logic br_en_reg
);

logic [31:0] pc_reg, pc_next,next,inst;
logic is_pending_mem_request_reg, is_pending_mem_request_next;
logic [63:0] order_next;
// logic br_en_reg;

// Branch prediction Values
localparam M = 3;
localparam N = 2;
localparam NUM_ENTRIES = 2048;
localparam WIDTH = 16;

// Branch prediction output
logic branch_predicted_taken;

// Internal Signals:
logic valid_wrout, valid_rout;

// Branch prediction registers
enum { read, write_taken, write_not_taken}  branch_table_state, branch_table_state_next;
logic [NUM_ENTRIES/(WIDTH/N) - 1 : 0]       valid;
logic [M - 1 : 0]                           br_hist;

// SRAM Inputs
logic   [$clog2(NUM_ENTRIES) - 1 : 0]       table_wraddr, last_table_wraddr, table_raddr, last_table_raddr;
logic                                       table_web;
logic   [WIDTH/N - 1: 0]                    table_wmask;
logic   [N - 1 : 0]                         table_in;

// SRAM Outputs
logic   [N - 1 : 0]                         table_wrout, table_rout;

// SRAM
mp_ooo_2_port_256_entry_16_bit branch_table (   .clk0(clk),
                                                .csb0('0),
                                                .web0(table_web),
                                                .addr0(table_wraddr),
                                                .wmask0(table_wmask),
                                                .din0(table_in),
                                                .dout0(table_wrout),
                                                .clk1(clk),
                                                .csb1('0),
                                                .web1('1),
                                                .addr1(table_raddr),
                                                .wmask1('0),
                                                .din1('x),
                                                .dout1(table_rout));

assign ufp_addr = pc_next;
assign pc = pc_reg;
assign pc_n = pc_next;

always_ff @(posedge clk) begin
    if (rst) begin
        pc_reg <= 32'h1eceb000;
        order_reg<= 64'b0;
        is_pending_mem_request_reg <= '0;
        br_en_reg <= '0;
    end 
    else begin
        pc_reg <= pc_next;
        order_reg<= order_next;
        is_pending_mem_request_reg <= is_pending_mem_request_next;
        if (branch_mispredict && is_pending_mem_request_reg && !ufp_resp) begin
            br_en_reg <= '1;
        end
        else if (ufp_resp || !is_pending_mem_request_reg) begin
            br_en_reg <= '0;
        end
    end


end

always_comb begin
    if (ufp_rdata[6:0]==op_b_br && !rst && branch_predicted_taken)
        next={{20{ufp_rdata[31]}}, ufp_rdata[7], ufp_rdata[30:25], ufp_rdata[11:8], 1'b0};
    else 
        next = 32'h4;
    
end

always_comb begin
    order_next =   (branch_mispredict) ? (new_fetch_order + 64'b1) :
                is_fetch_q_full ? order_reg :
                (!is_pending_mem_request_reg) ? (order_reg) : 
                (is_pending_mem_request_reg && ufp_resp && !br_en_reg) ? (order_reg + 64'b1) : order_reg;
    pc_next =   (branch_mispredict) ? (new_fetch_pc) :
                is_fetch_q_full ? pc_reg :
                (!is_pending_mem_request_reg) ? (pc_reg) : 
                (is_pending_mem_request_reg && ufp_resp && !br_en_reg) ? (pc_reg + next) : pc_reg;
    ufp_rmask = is_fetch_q_full ? 4'b0000 :
                (!is_pending_mem_request_reg) ? 4'b1111 : 
                (is_pending_mem_request_reg && ufp_resp && !br_en_reg) ? 4'b1111 : 4'b0000;
    is_pending_mem_request_next = (ufp_rmask != '0) ? 1'b1 : ufp_resp ? 1'b0 : is_pending_mem_request_reg;
end


// Valid Module, Seq Read and Seq Write
always_ff @ (posedge clk) begin
    if(rst) begin
        valid <= '0;
        valid_rout <= '0;
        valid_wrout <= '0;
    end else begin
        valid_rout <= valid[table_raddr[ $clog2(WIDTH/2) +: NUM_ENTRIES/(WIDTH/N) ]];
        valid_wrout <= valid[table_wraddr[$clog2(WIDTH/2) +: NUM_ENTRIES/(WIDTH/N) ]];
        if(!table_web)
            valid[table_wraddr] <= '1;
    end
end


endmodule
