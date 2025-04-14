module alu_exec
import rv32i_types::*;
#(
    parameter   NUM_UNITS = 1
)(
    input rs_to_alu_t rs_to_alu,

    input  logic    [31:0] ps1_value,
    input  logic    [31:0] ps2_value,

    // CDB entry that will be sent to the CDB arbiter
    output cdb_entry_t alu_to_queue_cdb_entry
);

logic [NUM_UNITS-1:0] alu_busy_reg;
logic [NUM_UNITS-1:0] alu_empty_reg;

logic br_en;

logic [31:0] a;
logic [31:0] b;

logic [2:0] aluop;
// logic [2:0] cmpop;

logic [31:0] aluout;

logic signed [31:0] as;
logic signed [31:0] bs;
logic unsigned [31:0] au;
logic unsigned [31:0] bu;

logic [31:0] rd_v;
logic [31:0] calculated_pc_next;

assign alu_to_queue_cdb_entry.rd = rs_to_alu.rd;
assign alu_to_queue_cdb_entry.pd = rs_to_alu.pd;
assign alu_to_queue_cdb_entry.valid = rs_to_alu.valid;
assign alu_to_queue_cdb_entry.rob_entry_idx = rs_to_alu.rob_entry_idx;
assign alu_to_queue_cdb_entry.rs1_value = a;
assign alu_to_queue_cdb_entry.rs2_value = b;
assign alu_to_queue_cdb_entry.value = rd_v;
assign alu_to_queue_cdb_entry.opcode = rs_to_alu.opcode;
assign alu_to_queue_cdb_entry.pc = rs_to_alu.pc;

assign alu_to_queue_cdb_entry.mem_addr ='0;
assign alu_to_queue_cdb_entry.mem_rmask='0;
assign alu_to_queue_cdb_entry.mem_wmask='0;
assign alu_to_queue_cdb_entry.mem_rdata='0;
assign alu_to_queue_cdb_entry.mem_wdata='0;
// TODO: this will change for jump instructions
assign alu_to_queue_cdb_entry.calculated_pc_next = calculated_pc_next;

    // Get the values for a and b
assign    a = ps1_value;
assign    b = (rs_to_alu.opcode == op_b_imm) ? rs_to_alu.imm : ps2_value;

    // Get the signed and unsigned values of a and b
assign    as = signed'(a);
assign    bs = signed'(b);
assign    au = unsigned'(a);
assign    bu = unsigned'(b);
assign    calculated_pc_next = rs_to_alu.pc + 32'h4;

    // Get the ALU operation

always_comb begin
    aluop = rs_to_alu.funct3;
    rd_v = 'x;

    if (rs_to_alu.valid == '1) begin
        unique case (rs_to_alu.opcode)
            op_b_imm: begin
                unique case (rs_to_alu.funct3)
                    arith_f3_slt: begin
                        rd_v = {31'd0, au < bu};
                    end
                    arith_f3_sltu: begin
                        rd_v = {31'd0, au < bu};
                    end
                    arith_f3_sr: begin
                        if (rs_to_alu.funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                        rd_v = aluout;
                    end
                    default: begin
                        aluop = rs_to_alu.funct3;
                        rd_v = aluout;
                    end
                endcase
            end
            op_b_reg: begin
                unique case (rs_to_alu.funct3)
                    arith_f3_slt: begin
                        rd_v = {31'd0, as < bs};
                    end
                    arith_f3_sltu: begin
                        rd_v = {31'd0, au < bu};
                    end
                    arith_f3_sr: begin
                        if (rs_to_alu.funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                        rd_v = aluout;
                    end
                    arith_f3_add: begin
                        if (rs_to_alu.funct7[5]) begin
                            aluop = alu_op_sub;
                        end else begin
                            aluop = alu_op_add;
                        end
                        rd_v = aluout;
                    end
                    default: begin
                        aluop = rs_to_alu.funct3;
                        rd_v = aluout;
                    end
                endcase
            end
            op_b_lui: begin
                rd_v = rs_to_alu.imm; // Load immediate into the upper 20 bits of the value
            end
            op_b_auipc: begin
                rd_v = rs_to_alu.imm + rs_to_alu.pc; // Load immediate into the upper 20 bits of the value
            end
            default: begin
                rd_v = 'x;
            end
        endcase
    end

end

always_comb begin
unique case (aluop)
        alu_op_add: aluout = au +   bu;
        alu_op_sll: aluout = au <<  bu[4:0];
        alu_op_sra: aluout = unsigned'(as >>> bu[4:0]);
        alu_op_sub: aluout = au -   bu;
        alu_op_xor: aluout = au ^   bu;
        alu_op_srl: aluout = au >>  bu[4:0];
        alu_op_or : aluout = au |   bu;
        alu_op_and: aluout = au &   bu;
        default   : aluout = 'x;
    endcase
end

endmodule

module alu_queue
import rv32i_types::*;
#(
    parameter   NUM_UNITS = 1
)(
    // TODO: need inputs from the ALU
    input logic clk,
    input logic rst,
    input cdb_entry_t cdb_entry_from_alu,
    input logic cdb_arb_dequeue,
    input logic res_station_select, // Selection signal from the reservation station
    output cdb_entry_t alu_queue_result, // Value in the queue
    output logic alu_queue_is_full, 
    output logic alu_is_ready // Signals to RS that the ALU is ready
);

logic [NUM_UNITS-1 : 0] res_station_select_reg;
// cdb_entry_t cdb_value;

logic queue_is_full, queue_is_empty;

assign alu_queue_is_full = ~queue_is_empty; // & res_station_select_reg;

// If the queue is empty and nothing is being enqueued into it, or if the queue is full and the CDB will dequeue it
// assign alu_is_ready = (queue_is_empty & ~(res_station_select_reg & cdb_entry_from_alu.valid)) | (queue_is_full & cdb_arb_dequeue);
assign alu_is_ready = ~queue_is_full & ~res_station_select_reg;// | (queue_is_full & cdb_arb_dequeue);

// Create a queue from the queue module
queue #(
    .WIDTH($bits(cdb_entry_t)),
    .LENGTHEXP(1)
) alu_queue (
    .clk(clk),
    .rst(rst),
    .wdata(cdb_entry_from_alu), // write incoming ALU result to the queue
    .enqueue(res_station_select & cdb_entry_from_alu.valid), // enqueue if the reservation station has picked this ALU unit the previous cycle
    .rdata(alu_queue_result), // read the ALU result from the queue
    .dequeue(cdb_arb_dequeue), // dequeue if the CDB arbiter has picked this ALU unit
    .is_full(queue_is_full), // Mark if this queue is full
    .is_empty(queue_is_empty) // Mark if this queue is empty
);


// always_ff @( posedge clk ) begin
//     if (rst) begin
//         queue_is_full<='0;
//         alu_queue_result<='0;
//     end
//     if (res_station_select & cdb_entry_from_alu.valid) begin
//         alu_queue_result<=cdb_entry_from_alu;
//         queue_is_full<='1;
//     end
//     else if (cdb_arb_dequeue) begin
//         alu_queue_result<='0;
//         queue_is_full<='0;
//     end
// end

// // Sequential block to set the res_station_select_reg
always_ff @(posedge clk) begin
        res_station_select_reg <= res_station_select;
end

endmodule
