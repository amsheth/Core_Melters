module multiplier_exec import rv32i_types::*; #(
    parameter NUM_STAGES = 3
)(
    // Like alu_exec
    input   rs_to_mult_t    rs_to_mult,
    input   logic [31: 0]   ps1_value,
    input   logic [31: 0]   ps2_value,

    // Like alu_queue
    input   logic           clk, rst,
    input   logic           cdb_arb_dequeue,          // CDB Arbiter has picked this signal
    output  cdb_entry_t     mult_queue_result,
    output  logic           mult_queue_is_full_to_CDB,      // Signal sent to CDB Arbiter
    output  logic           mult_is_ready_to_RS            // Signal sent to RS arbiter
    

);

// Flag to store the current state of the multiplier, initially busy

logic   [31: 0] mult_queue_result_value;
enum logic [1:0] {
    busy,
    not_busy = 2'b01,
    reset
} state;

// Operands are 1 bit bigger than needed so that signed and non-signed multiplication can be handled easily
logic [32:0] op_a;
logic [32:0] op_b;
logic [65:0] product;

// Register to hold the input while the data is being processed
typedef struct packed {
    logic [31:0] ps1_value;
    logic [31:0] ps2_value;
    mult_pipe_t input_data;
} shadow;

shadow mult_pipe[NUM_STAGES];

assign mult_pipe[0].input_data.pd               = rs_to_mult.pd;
assign mult_pipe[0].input_data.rd               = rs_to_mult.rd;
assign mult_pipe[0].input_data.funct3           = rs_to_mult.funct3;
assign mult_pipe[0].input_data.opcode           = rs_to_mult.opcode;
assign mult_pipe[0].input_data.rob_entry_idx    = rs_to_mult.rob_entry_idx;
assign mult_pipe[0].input_data.pc               = rs_to_mult.pc;
assign mult_pipe[0].input_data.valid            = rs_to_mult.valid;
assign mult_pipe[0].ps1_value                   = ps1_value;
assign mult_pipe[0].ps2_value                   = ps2_value;


logic mult_is_not_done;

assign mult_queue_is_full_to_CDB = mult_pipe[NUM_STAGES-1].input_data.valid;

assign mult_is_not_done= !mult_pipe[NUM_STAGES-1].input_data.valid|cdb_arb_dequeue;
assign mult_is_ready_to_RS= mult_is_not_done;

// Multiplier Input datapath
always_comb begin
    //UNEXPECTED_FUNCT3_SENT_TO_MULTIPLIER : assert (res_station_select_from_RS -> (rs_to_mult.funct3[2] == 1'b0));
    unique case(rs_to_mult.funct3[1:0])
        2'b00: begin // MUL -- lower 32-bit -- signed 32-bit times signed 32-bit
            op_a = {ps1_value[31],ps1_value};
            op_b = {ps2_value[31],ps2_value};
        end
        2'b01: begin // MULH -- upper 32-bit -- signed 32-bit times signed 32-bit
            op_a = {ps1_value[31],ps1_value};
            op_b = {ps2_value[31],ps2_value};
        end
        2'b10: begin // MULHSU -- upper 32-bit -- signed 32-bit times unsigned 32-bit  
            op_a = {ps1_value[31],ps1_value};
            op_b = {1'b0,ps2_value};
        end
        default: begin//, 2'b11: begin // MULHU -- upper 32-bit -- unsigned 32-bit times unsigned 32-bit
            op_a = {1'b0,ps1_value};
            op_b = {1'b0,ps2_value};
        end
    endcase
end

// Multiplier IP
DW_mult_pipe #( .a_width(33), 
                .b_width(33),
                .num_stages(NUM_STAGES),
                .rst_mode(2),
                .stall_mode(1))
            mult_ip (
                .clk(clk),
                .rst_n(!rst),
                .en(mult_is_not_done),
                .tc('1),
                .a(op_a),
                .b(op_b),
                .product(product)
            );



always_ff @( posedge clk ) begin
    if (rst) begin
        for (int i=1;i<NUM_STAGES;i++)
            mult_pipe[i]<='0;
    end
    else if (mult_is_not_done) begin
        mult_pipe[1]<=mult_pipe[0];
        // generate
        // if (NUM_STAGES>2) begin
        for (int i=2;i<NUM_STAGES;i++)
            mult_pipe[i]<=mult_pipe[i-1];
        // end
        // endgenerate
    end
end



    // mult_queue_result               = '0;
assign mult_queue_result.rd                 = mult_pipe[NUM_STAGES-1].input_data.rd;
assign mult_queue_result.pd                 = mult_pipe[NUM_STAGES-1].input_data.pd;
assign mult_queue_result.valid              = mult_pipe[NUM_STAGES-1].input_data.valid;
assign mult_queue_result.rob_entry_idx      = mult_pipe[NUM_STAGES-1].input_data.rob_entry_idx;
assign mult_queue_result.rs1_value          = mult_pipe[NUM_STAGES-1].ps1_value;
assign mult_queue_result.rs2_value          = mult_pipe[NUM_STAGES-1].ps2_value;
assign mult_queue_result.value              = mult_pipe[NUM_STAGES-1].input_data.valid ? mult_queue_result_value : '0;
assign mult_queue_result.pc                 = mult_pipe[NUM_STAGES-1].input_data.pc;
assign mult_queue_result.calculated_pc_next = mult_pipe[NUM_STAGES-1].input_data.pc + 32'd4;
assign mult_queue_result.opcode             = mult_pipe[NUM_STAGES-1].input_data.opcode;
assign mult_queue_result.mem_addr           = '0;
assign mult_queue_result.mem_rmask          = '0;
assign mult_queue_result.mem_wmask          = '0;
assign mult_queue_result.mem_rdata          = '0;
assign mult_queue_result.mem_wdata          = '0;
assign mult_queue_result_value              = (mult_pipe[NUM_STAGES-1].input_data.funct3[1:0]=='0)? product[31:0]:product[63:32];


endmodule

