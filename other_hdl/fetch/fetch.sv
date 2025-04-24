module fetch
import rv32i_types::*;
(
    input logic clk,
    input logic rst,
    input logic ufp_resp,
    input logic is_fetch_q_full,
    input logic branch_mispredict,
    input logic [63:0] new_fetch_order,
    // input logic stall,
    input  logic [31:0]   ufp_rdata,
    output logic [31:0] ufp_addr,
    output logic [31:0] pc,
    output logic [31:0] pc_n,
    output logic [3:0] ufp_rmask,
    output logic [63:0] order_reg
);

logic [31:0] pc_reg, pc_next,next,inst;
logic is_pending_mem_request_reg, is_pending_mem_request_next;
logic [63:0] order_next;

assign ufp_addr = pc_next;
assign pc = pc_reg;
assign pc_n = pc_next;

always_ff @(posedge clk) begin
    if (rst) begin
        pc_reg <= 32'h1eceb000;
        order_reg<= 64'b0;
        is_pending_mem_request_reg <= '0;
    end else begin
        pc_reg <= pc_next;
        order_reg<= order_next;
        is_pending_mem_request_reg <= is_pending_mem_request_next;
    end
end

always_comb begin
    if (ufp_rdata[6:0]==op_b_br && !rst)
        next={{20{ufp_rdata[31]}}, ufp_rdata[7], ufp_rdata[30:25], ufp_rdata[11:8], 1'b0};
    else 
        next = 32'h4;
    
end

always_comb begin
    order_next =   (branch_mispredict) ? (new_fetch_order + 64'b1) :
                is_fetch_q_full ? order_reg :
                (!is_pending_mem_request_reg) ? (order_reg) : 
                (is_pending_mem_request_reg && ufp_resp) ? (order_reg + 64'b1) : order_reg;
    pc_next =   is_fetch_q_full ? pc_reg :
                (!is_pending_mem_request_reg) ? (pc_reg) : 
                (is_pending_mem_request_reg && ufp_resp) ? (pc_reg + next) : pc_reg;
    ufp_rmask = is_fetch_q_full ? 4'b0000 :
                (!is_pending_mem_request_reg) ? 4'b1111 : 
                (is_pending_mem_request_reg && ufp_resp) ? 4'b1111 : 4'b0000;
    is_pending_mem_request_next = (ufp_rmask != '0) ? 1'b1 : ufp_resp ? 1'b0 : is_pending_mem_request_reg;
end

endmodule
