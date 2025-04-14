module decode_rename 
import rv32i_types::*;
#(
    parameter P_REG_IDX_NUM_BITS = PHYS_REG_IDX,
    parameter ARCH_REG_IDX_NUM_BITS = ARCH_REG_IDX
)
(
    input logic [159 + BRANCH_PRED_M:0] decode_ins, // instruction to be decoded
    input logic [PHYS_REG_IDX:0] free_list_next_p_reg, // Input the next available physical register from free list
    input RAT_to_decode_rename_t rat_to_decode, // Requested values from the RAT
    input logic stall,
    input logic is_ins_queue_empty,
    output logic dequeue_ins_queue, // Signal dequeue to the instruction queue
    output logic dequeue_free_list, // Signal dequeue to the free list
    output decode_rename_to_RAT_t decode_to_RAT, // Output to the RAT (we want RAT to respond to this request)
    output decode_rename_to_dispatch_t decode_to_dispatch // Output to the dispatch module
);

// logic dequeue_ins_queue;
logic [31:0] imm, i_imm, s_imm, b_imm, u_imm, j_imm;
logic [ARCH_REG_IDX_NUM_BITS:0] rs1_s, rs2_s, rd_s;
logic [P_REG_IDX_NUM_BITS:0] ps1_s, ps2_s, pd_s;
logic ps1_valid, ps2_valid;
logic [6:0] opcode;

assign dequeue_ins_queue = (~stall); // Only dequeue the instruction queue if we do not have a stall
assign opcode = decode_ins[6:0];


assign i_imm = {{21{decode_ins[31]}}, decode_ins[30:20]};
assign s_imm = {{21{decode_ins[31]}}, decode_ins[30:25], decode_ins[11:7]};
assign b_imm = {{20{decode_ins[31]}}, decode_ins[7], decode_ins[30:25], decode_ins[11:8], 1'b0};
assign u_imm = {decode_ins[31:12], 12'h000};
assign j_imm = {{12{decode_ins[31]}}, decode_ins[19:12], decode_ins[20], decode_ins[30:21], 1'b0};
// U and J types don't have rs1
// assign rs1_s = decode_ins[19:15] && (~((opcode == op_b_lui) | (opcode == op_b_auipc) | (opcode == op_b_jal)));

assign rs1_s = (opcode inside {op_b_lui, op_b_auipc, op_b_jal}) ? '0 : decode_ins[19:15];

// I, U and J type instructions do not have rs2

assign rs2_s = (opcode inside {op_b_imm, op_b_load, op_b_jalr, op_b_lui, op_b_auipc, op_b_jal}) ? '0 : decode_ins[24:20];

// assign rs2_s = decode_ins[24:20] && (~((opcode == op_b_imm) | (opcode == op_b_load) | (opcode == op_b_jalr) | (opcode == op_b_lui) | (opcode == op_b_auipc) | (opcode == op_b_jal)));
// S and B types dont have a destination register
assign rd_s = (opcode inside {op_b_store, op_b_br}) ? '0 : decode_ins[11:7];
// assign rd_s = decode_ins[11:7] && (~((opcode == op_b_store) | (opcode == op_b_br)));

assign decode_to_dispatch.pc = decode_ins[63:32];
assign decode_to_dispatch.pc_next = decode_ins[95:64];
assign decode_to_dispatch.valid = !is_ins_queue_empty;//(~stall);
assign decode_to_dispatch.ps1_s = ps1_s;
assign decode_to_dispatch.ps2_s = ps2_s;
assign decode_to_dispatch.pd_s = pd_s;
assign decode_to_dispatch.ps1_valid = ps1_valid;
assign decode_to_dispatch.ps2_valid = ps2_valid;
assign decode_to_dispatch.funct3 = decode_ins[14:12];
assign decode_to_dispatch.funct7 = decode_ins[31:25];
assign decode_to_dispatch.br_hist = decode_ins[160 +: BRANCH_PRED_M];
assign decode_to_dispatch.opcode = decode_ins[6:0];
assign decode_to_dispatch.imm = imm;
assign decode_to_dispatch.regf_we = 'x;//~((opcode == op_b_store) | (opcode == op_b_br)) &
                                    // (~stall); // TODO: account for stalling
assign decode_to_dispatch.rd_s  = rd_s;
assign decode_to_dispatch.rs1_s = rs1_s;
assign decode_to_dispatch.rs2_s = rs2_s;
assign decode_to_dispatch.order = decode_ins[159:96];
assign decode_to_dispatch.inst = decode_ins[31:0];

// Send request to RAT
assign decode_to_RAT.rd = rd_s;
assign decode_to_RAT.rs1 = rs1_s;
assign decode_to_RAT.rs2 = rs2_s;
assign decode_to_RAT.pd = pd_s;
assign decode_to_RAT.write_en = (~stall);


always_comb begin
    // Set immediate value based on the opcode
    unique case(opcode)
        op_b_imm, op_b_load, op_b_jalr: imm = i_imm; // I-type instructions
        op_b_store: imm = s_imm; // S-type instructions
        op_b_br: imm = b_imm; // B-type instructions
        op_b_lui, op_b_auipc: imm = u_imm; // U-type instructions
        op_b_jal: imm = j_imm; // J-type instructions
        default: imm = '0; // Default to 0 for all other opcodes
    endcase
end


// Architectural to physical register mapping
always_comb begin
    pd_s = '0;
    ps1_s = '0;
    ps2_s = '0;
    ps1_valid = '0;
    ps2_valid = '0;
    dequeue_free_list = '0;

    if (~stall) begin // Only decode if we are not stalled 
        unique case(opcode)
            op_b_reg: begin
                // Request a physical register from free list for rd, add to RAT
                pd_s = (rd_s != '0) ? free_list_next_p_reg : '0;
                dequeue_free_list = (rd_s != '0) ? '1 : '0;

                // Look up RS1 and RS2 in the RAT
                ps1_s = rat_to_decode.ps1;
                ps2_s = rat_to_decode.ps2;
                ps1_valid = rat_to_decode.ps1_valid;
                ps2_valid = rat_to_decode.ps2_valid;
            end
            op_b_imm, op_b_load, op_b_jalr: begin
                // Request a physical register from free list for rd, add to RAT
                pd_s = (rd_s != '0) ? free_list_next_p_reg : '0;
                dequeue_free_list = (rd_s != '0) ? 1'b1 : '0;

                // Look up RS1 in the RAT
                ps1_s = rat_to_decode.ps1;
                ps1_valid = rat_to_decode.ps1_valid;
                ps2_valid = '1; // Immediate value is always valid
            end
            op_b_store, op_b_br: begin
                // Look up RS1 and RS2 in the RAT
                ps1_s = rat_to_decode.ps1;
                ps2_s = rat_to_decode.ps2;
                ps1_valid = rat_to_decode.ps1_valid;
                ps2_valid = rat_to_decode.ps2_valid;
            end
            op_b_lui, op_b_auipc, op_b_jal: begin
                // Request a physical register from free list for rd, add to RAT
                pd_s = (rd_s != '0) ? free_list_next_p_reg : '0;
                dequeue_free_list = (rd_s != '0) ? '1 : '0;
            end
            default: begin
                // Default to 0 for all other opcodes
                pd_s = '0;
                ps1_s = '0;
                ps2_s = '0;
                ps1_valid = '0;
                ps2_valid = '0;
            end
        endcase

        // Special case for rs1 and rs2 being 0
        if (rs1_s == '0) begin
            ps1_valid = '1;
        end
        if (rs2_s == '0) begin
            ps2_valid = '1;
        end
    end
end
    
endmodule
