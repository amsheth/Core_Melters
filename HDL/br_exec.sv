module br_exec
import rv32i_types::*;
#(
    parameter   NUM_UNITS = 1
)(
    input rs_to_br_t rs_to_br,
    input  logic           clk,
    input  logic           rst,
    input  logic    [31:0] ps1_value,
    input  logic    [31:0] ps2_value,
    input  logic           cdb_arb_dequeue,
    input  logic           res_station_select, 

    // CDB entry that will be sent to the CDB arbiter
    output cdb_entry_t br_queue_result,
    output logic br_queue_is_full,
    output logic br_is_ready,
    output logic br_update,
    output logic br_taken,
    output logic [31:0] br_pc
);


cdb_entry_t br_to_queue_cdb_entry;
logic br_en, br_en_prev;
logic unsigned [31:0] au;
logic unsigned [31:0] bu;
logic signed   [31:0] as;
logic signed   [31:0] bs;
logic [NUM_UNITS-1 : 0] res_station_select_reg;
logic queue_is_full, queue_is_empty, queue_is_full_prev;

assign br_queue_is_full = ~queue_is_empty;
assign br_is_ready = !queue_is_full && !res_station_select_reg;
// Get the signed and unsigned values of a and b
assign as = signed'(ps1_value);
assign bs = signed'(ps2_value);
assign au = unsigned'(ps1_value);
assign bu = unsigned'(ps2_value);


always_comb begin 
    if (rs_to_br.opcode == op_b_br) begin
        unique case (rs_to_br.funct3)
                branch_f3_beq : br_en = (au == bu);
                branch_f3_bne : br_en = (au != bu);
                branch_f3_blt : br_en = (as <  bs);
                branch_f3_bge : br_en = (as >=  bs);
                branch_f3_bltu: br_en = (au <  bu);
                branch_f3_bgeu: br_en = (au >=  bu);
                default       : br_en = 1'b0;
        endcase
    end 
    else 
        br_en=1'b1;
end

assign br_to_queue_cdb_entry.pc = rs_to_br.pc;
assign br_to_queue_cdb_entry.opcode = rs_to_br.opcode;
assign br_to_queue_cdb_entry.rd = rs_to_br.rd;
assign br_to_queue_cdb_entry.pd = rs_to_br.pd;
assign br_to_queue_cdb_entry.value = (rs_to_br.opcode == op_b_jal || rs_to_br.opcode == op_b_jalr) ? rs_to_br.pc +32'h4 : '0;
assign br_to_queue_cdb_entry.valid = rs_to_br.valid;
assign br_to_queue_cdb_entry.rob_entry_idx = rs_to_br.rob_entry_idx;
assign br_to_queue_cdb_entry.rs1_value = ps1_value;
assign br_to_queue_cdb_entry.rs2_value = ps2_value;
assign br_to_queue_cdb_entry.mem_addr ='0;
assign br_to_queue_cdb_entry.mem_rmask='0;
assign br_to_queue_cdb_entry.mem_wmask='0;
assign br_to_queue_cdb_entry.mem_rdata='0;
assign br_to_queue_cdb_entry.mem_wdata='0;
always_comb begin
    br_to_queue_cdb_entry.calculated_pc_next = (br_en) ? rs_to_br.pc + rs_to_br.imm : rs_to_br.pc + 32'h4;
    if (rs_to_br.opcode == op_b_jalr)
        br_to_queue_cdb_entry.calculated_pc_next = (au +rs_to_br.imm)& 32'hfffffffe;
    //if (rs_to_br.opcode == op_b_jal)
    //    br_to_queue_cdb_entry.calculated_pc_next = (as +rs_to_br.imm)& 32'hfffffffe;
end


queue #(
    .WIDTH($bits(cdb_entry_t)),
    .LENGTHEXP(0)
) alu_queue (
    .clk(clk),
    .rst(rst),
    .wdata(br_to_queue_cdb_entry), // write incoming ALU result to the queue
    .enqueue(res_station_select & br_to_queue_cdb_entry.valid), // enqueue if the reservation station has picked this ALU unit the previous cycle
    .rdata(br_queue_result), // read the ALU result from the queue
    .dequeue(cdb_arb_dequeue), // dequeue if the CDB arbiter has picked this ALU unit
    .is_full(queue_is_full), // Mark if this queue is full
    .is_empty(queue_is_empty) // Mark if this queue is empty
);
// always_ff @( posedge clk ) begin
//     queue_is_full_prev <= queue_is_full;
//     br_en_prev <= br_en;

//     if (rst) begin
//         queue_is_full<='0;
//         br_queue_result<='0;
//     end
//     if (res_station_select & br_to_queue_cdb_entry.valid) begin
//         br_queue_result<=br_to_queue_cdb_entry;
//         queue_is_full<='1;
//     end
//     else if (cdb_arb_dequeue) begin
//         br_queue_result<='0;
//         queue_is_full<='0;
//     end
// end

always_ff @(posedge clk) begin
    res_station_select_reg <= res_station_select;
    br_en_prev <= br_en;
    queue_is_full_prev <= ~queue_is_empty;
end

// Branch Predictor Update Signals, sent on the cycle after br_queue_is_full's rising edge
always_comb begin
    if(~queue_is_full_prev & br_queue_is_full & br_queue_result.opcode == op_b_br) begin
        br_update = '1;
        br_taken = br_en_prev;
        br_pc = br_queue_result.pc;
    end else begin
        br_update = '0;
        br_taken = '0;
        br_pc = '0;
    end
end


endmodule
