module dispatch
import rv32i_types::*;
(
    input decode_rename_to_dispatch_t decode_to_dispatch, // Input from decode module
    input ROB_to_dispatch_t rob_to_dispatch, // RoB sends in the entry # and whether it is full
    input logic rs_is_full, // Reservation station sends whether it is full
    input logic alu_rs_is_full, // Reservation station sends whether it is full
    input logic br_rs_is_full,
    input logic ld_rs_is_full,
    input logic st_q_is_full,
    input logic fetch_q_empty,
    input logic freelist_is_empty,
    output dispatch_to_ROB_t dispatch_to_rob, // Value to enqueue in the RoB
    output dispatch_to_rs_t dispatch_to_rs, // Output to reservation station
    output dispatch_to_rs_t dispatch_to_alu, // Output to reservation station
    output dispatch_to_rs_t dispatch_to_br, // Output to reservation station
    output dispatch_to_lsq_t dispatch_to_ld_rs, // Output to the Load RS
    output dispatch_to_lsq_t dispatch_to_st_q, // Output to the Store Queue
    output logic dispatch_stall // Stall due to the RoB or R.S. being full
);

// Signals that are used a few times (whether the instruction corresponds to RS or LSQ, respectively)
logic is_rs_opcode;
assign is_rs_opcode = (decode_to_dispatch.opcode == op_b_reg && decode_to_dispatch.funct7[0]);
logic is_br_opcode;
assign is_br_opcode = decode_to_dispatch.opcode inside {op_b_br,op_b_jal, op_b_jalr};
logic is_alu_opcode;
assign is_alu_opcode = decode_to_dispatch.opcode inside {op_b_imm,op_b_auipc,op_b_lui} || (decode_to_dispatch.opcode == op_b_reg && !decode_to_dispatch.funct7[0]);
logic is_ld_rs_opcode;
assign is_ld_rs_opcode = decode_to_dispatch.opcode inside {op_b_load};
logic is_st_q_opcode;
assign is_st_q_opcode = decode_to_dispatch.opcode inside {op_b_store};

dispatch_to_ROB_only_data_t dispatch_to_rob_data;





// Dispatch stall is high if ROB is full, if we receive a RS-bound instr and RS is full, or if we receive a LSQ-bound instr and LSQ is full
always_comb begin
    
    dispatch_stall = '0;
    if(rob_to_dispatch.is_rob_full | ~decode_to_dispatch.valid | fetch_q_empty | freelist_is_empty) begin
        // Stall if any basic resource is blocked
        dispatch_stall = '1;
    end 
    if (is_rs_opcode & rs_is_full)
        dispatch_stall = '1;
    if (is_br_opcode & br_rs_is_full)
        dispatch_stall = '1;
    if (is_alu_opcode & alu_rs_is_full)
        dispatch_stall = '1;
    if (is_ld_rs_opcode & ld_rs_is_full)
        dispatch_stall = '1;
    if (is_st_q_opcode & st_q_is_full)
        dispatch_stall = '1;
    
end


// Send a request to the RoB to allocate a new entry
always_comb begin

    // Send the new instruction to the RoB and Reservation Station
    // Only do so if ROB has space, RS has space, and the received value from decode/rename is valid
    if (~dispatch_stall) begin
        // Ensure that the condition for full is not true
        // ROB_IS_FULL : assert(rob_to_dispatch.is_rob_full != '1);
        // RS_IS_FULL : assert(rs_is_full != '1);

        // Send the instruction to the RoB
        dispatch_to_rob_data.rd = decode_to_dispatch.rd_s;
        dispatch_to_rob_data.pc = decode_to_dispatch.pc;
        dispatch_to_rob_data.pc_next = decode_to_dispatch.pc_next;
        dispatch_to_rob_data.pd = decode_to_dispatch.pd_s;
        dispatch_to_rob_data.opcode = decode_to_dispatch.opcode;
        dispatch_to_rob_data.order = decode_to_dispatch.order;
        dispatch_to_rob_data.calculated_pc_next = 32'hXXXXXX54;
        dispatch_to_rob_data.br_hist = decode_to_dispatch.br_hist;

        
        dispatch_to_rob.dispatch_to_ROB_only_data = dispatch_to_rob_data;
        dispatch_to_rob.enqueue_rob = '1;
        // dispatch_to_rob.rvfi = '0; // TODO: handle RVFI

        dispatch_to_rob.rvfi.valid     =  '0;
        dispatch_to_rob.rvfi.order     =  decode_to_dispatch.order;
        dispatch_to_rob.rvfi.inst      =  decode_to_dispatch.inst;
        dispatch_to_rob.rvfi.rs1_addr  =  decode_to_dispatch.rs1_s;
        dispatch_to_rob.rvfi.rs2_addr  =  decode_to_dispatch.rs2_s;
        dispatch_to_rob.rvfi.rs1_rdata =  'x;
        dispatch_to_rob.rvfi.rs2_rdata =  'x;
        dispatch_to_rob.rvfi.rd_addr   =  decode_to_dispatch.rd_s;
        dispatch_to_rob.rvfi.rd_wdata  =  'x;
        dispatch_to_rob.rvfi.pc_rdata  =  decode_to_dispatch.pc;
        dispatch_to_rob.rvfi.pc_wdata  =  decode_to_dispatch.pc_next;
        dispatch_to_rob.rvfi.mem_addr  =  '0;
        dispatch_to_rob.rvfi.mem_rmask =  '0 ;
        dispatch_to_rob.rvfi.mem_wmask =  '0;
        dispatch_to_rob.rvfi.mem_rdata =  '0;
        dispatch_to_rob.rvfi.mem_wdata =  '0;

        // Send the instruction to the Reservation Station
        if (is_rs_opcode) begin
            dispatch_to_rs.ps1_valid = decode_to_dispatch.ps1_valid;
            dispatch_to_rs.ps2_valid = decode_to_dispatch.ps2_valid;
            dispatch_to_rs.ps1 = decode_to_dispatch.ps1_s;
            dispatch_to_rs.ps2 = decode_to_dispatch.ps2_s;
            dispatch_to_rs.pd = decode_to_dispatch.pd_s;
            dispatch_to_rs.rd = decode_to_dispatch.rd_s;
            dispatch_to_rs.funct3 = decode_to_dispatch.funct3;
            dispatch_to_rs.funct7 = decode_to_dispatch.funct7;
            dispatch_to_rs.opcode = decode_to_dispatch.opcode;
            dispatch_to_rs.imm = decode_to_dispatch.imm;
            dispatch_to_rs.rob_entry_idx = rob_to_dispatch.rob_entry_idx;
            dispatch_to_rs.pc = decode_to_dispatch.pc;
            dispatch_to_rs.valid = decode_to_dispatch.valid;
        end else begin
            dispatch_to_rs = 'x;
            dispatch_to_rs.valid = '0;
        end
        if (is_br_opcode) begin
            dispatch_to_br.ps1_valid = decode_to_dispatch.ps1_valid;
            dispatch_to_br.ps2_valid = decode_to_dispatch.ps2_valid;
            dispatch_to_br.ps1 = decode_to_dispatch.ps1_s;
            dispatch_to_br.ps2 = decode_to_dispatch.ps2_s;
            dispatch_to_br.pd = decode_to_dispatch.pd_s;
            dispatch_to_br.rd = decode_to_dispatch.rd_s;
            dispatch_to_br.funct3 = decode_to_dispatch.funct3;
            dispatch_to_br.funct7 = decode_to_dispatch.funct7;
            dispatch_to_br.opcode = decode_to_dispatch.opcode;
            dispatch_to_br.imm = decode_to_dispatch.imm;
            dispatch_to_br.rob_entry_idx = rob_to_dispatch.rob_entry_idx;
            dispatch_to_br.pc = decode_to_dispatch.pc;
            dispatch_to_br.valid = decode_to_dispatch.valid;
        end else begin
            dispatch_to_br = 'x;
            dispatch_to_br.valid = '0;
        end
        if (is_alu_opcode) begin
            dispatch_to_alu.ps1_valid = decode_to_dispatch.ps1_valid;
            dispatch_to_alu.ps2_valid = decode_to_dispatch.ps2_valid;
            dispatch_to_alu.ps1 = decode_to_dispatch.ps1_s;
            dispatch_to_alu.ps2 = decode_to_dispatch.ps2_s;
            dispatch_to_alu.pd = decode_to_dispatch.pd_s;
            dispatch_to_alu.rd = decode_to_dispatch.rd_s;
            dispatch_to_alu.funct3 = decode_to_dispatch.funct3;
            dispatch_to_alu.funct7 = decode_to_dispatch.funct7;
            dispatch_to_alu.opcode = decode_to_dispatch.opcode;
            dispatch_to_alu.imm = decode_to_dispatch.imm;
            dispatch_to_alu.rob_entry_idx = rob_to_dispatch.rob_entry_idx;
            dispatch_to_alu.pc = decode_to_dispatch.pc;
            dispatch_to_alu.valid = decode_to_dispatch.valid;
        end else begin
            dispatch_to_alu = 'x;
            dispatch_to_alu.valid = '0;
        end
        if (is_ld_rs_opcode) begin
            dispatch_to_ld_rs.ps1_valid = decode_to_dispatch.ps1_valid;
            dispatch_to_ld_rs.ps2_valid = decode_to_dispatch.ps2_valid;
            dispatch_to_ld_rs.ps1 = decode_to_dispatch.ps1_s;
            dispatch_to_ld_rs.ps2 = decode_to_dispatch.ps2_s;
            dispatch_to_ld_rs.pd = decode_to_dispatch.pd_s;
            dispatch_to_ld_rs.rd = decode_to_dispatch.rd_s;
            dispatch_to_ld_rs.funct3 = decode_to_dispatch.funct3;
            dispatch_to_ld_rs.opcode = decode_to_dispatch.opcode;
            dispatch_to_ld_rs.imm = decode_to_dispatch.imm;
            dispatch_to_ld_rs.rob_entry_idx = rob_to_dispatch.rob_entry_idx;
            dispatch_to_ld_rs.pc = decode_to_dispatch.pc;
            dispatch_to_ld_rs.valid = decode_to_dispatch.valid;
        end else begin
            dispatch_to_ld_rs = 'x;
            dispatch_to_ld_rs.valid = '0;
        end
        if (is_st_q_opcode) begin
            dispatch_to_st_q.ps1_valid = decode_to_dispatch.ps1_valid;
            dispatch_to_st_q.ps2_valid = decode_to_dispatch.ps2_valid;
            dispatch_to_st_q.ps1 = decode_to_dispatch.ps1_s;
            dispatch_to_st_q.ps2 = decode_to_dispatch.ps2_s;
            dispatch_to_st_q.pd = decode_to_dispatch.pd_s;
            dispatch_to_st_q.rd = decode_to_dispatch.rd_s;
            dispatch_to_st_q.funct3 = decode_to_dispatch.funct3;
            dispatch_to_st_q.opcode = decode_to_dispatch.opcode;
            dispatch_to_st_q.imm = decode_to_dispatch.imm;
            dispatch_to_st_q.rob_entry_idx = rob_to_dispatch.rob_entry_idx;
            dispatch_to_st_q.pc = decode_to_dispatch.pc;
            dispatch_to_st_q.valid = decode_to_dispatch.valid;
        end else begin
            dispatch_to_st_q = 'x;
            dispatch_to_st_q.valid = '0;
        end

    end 
    else begin
        // ROB is full, resend the previous instruction
        dispatch_to_rob = '0;
        dispatch_to_rs = 'x;
        dispatch_to_rs.valid = '0;
        dispatch_to_ld_rs = 'x;
        dispatch_to_ld_rs.valid = '0;
        dispatch_to_st_q = 'x;
        dispatch_to_st_q.valid = '0;
        dispatch_to_alu = 'x;
        dispatch_to_alu.valid = '0;
        dispatch_to_br = 'x;
        dispatch_to_br.valid = '0;
        // RoB is full, do not send any instruction
        dispatch_to_rob_data = '0; // Never used and always set to 0
    end
end

endmodule
