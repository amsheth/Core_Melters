// This is a 32 bit divider, made to model alu_exec.sv

// NOTE : There is a >1 cycle delay in the output of the divider, so
// there should be a shadow shift register which makes sure that
// the divider output is valid

// NOTE: This divider shouldn't get selected for atleast 3 cycles after reset goes low
// NOTE: 3 cycles after reset, this divider will generate div_queue_is_full_to_CDB signal 
//       containing a garbage value.

module divider_exec import rv32i_types::*; #(
    parameter NUM_STAGES = 33
)(
    // Like alu_exec
    input   rs_to_div_t     rs_to_div,
    input   logic [31: 0]   ps1_value,
    input   logic [31: 0]   ps2_value,

    // Like alu_queue
    input   logic           clk, rst,
    input   logic           cdb_arb_dequeue,          // CDB Arbiter has picked this signal
    input   logic           res_station_select_from_RS,       // Signal coming from RS arbiter
    output  cdb_entry_t     div_queue_result,
    output  logic           div_queue_is_full_to_CDB,      // Signal sent to CDB Arbiter
    output  logic           div_is_ready_to_RS            // Signal sent to RS arbiter
);

// Flag to store the current state of the divider, initially busy

logic   [31: 0] div_queue_result_value;
rs_to_div_t     div_to_cdb_arb;
enum logic [1:0] {
    busy,
    not_busy = 2'b01,
    reset
} state;

// Operands are 1 bit bigger than needed so that signed and non-signed divide can be handled easily
logic [32:0] op_a;
logic [32:0] op_b;
logic [32:0] quotient;
logic [32:0] remainder;
logic divide_by_zero;

// Register to hold the input while the data is being processed
struct packed {
    rs_to_div_t data;
    logic [31:0] ps1_value_shadow;
    logic [31:0] ps2_value_shadow;
} shadow_input;

// Overflow flag based on shadow_input to look for

logic shadow_overflow_flag;
assign shadow_overflow_flag = (shadow_input.ps1_value_shadow == 32'h80000000) && (shadow_input.ps2_value_shadow == '1);

logic div_is_done;
assign div_queue_is_full_to_CDB = div_is_done && state == busy;

// State Machine Logic
always_ff @ (posedge clk) begin
    if(rst) begin
        state <= reset;
    end else begin
        case(state)
            busy: begin
                state <= cdb_arb_dequeue ? not_busy : state;
            end
            not_busy: begin
                state <= res_station_select_from_RS ? busy : state;
                shadow_input.data <= rs_to_div;
                shadow_input.ps1_value_shadow <= ps1_value;
                shadow_input.ps2_value_shadow <= ps2_value;
            end
            default: begin // reset
                // Right after reset, the div generates an erroneous output
                // The output can be ignored.
                state <= div_is_done ? not_busy : state;
                shadow_input <= '0;
            end
        endcase;
    end
end

// Divider Input datapath
always_comb begin
    op_a = '0;
    op_b = '0;
    if(!rst) begin
        //UNEXPECTED_FUNCT3_SENT_TO_DIVIDER : assert (res_station_select_from_RS -> (rs_to_div.funct3[2] == 1'b1));
        unique case(rs_to_div.funct3[0])
            
            // DIV - Signed 32-bit division
            1'b0: begin
                op_a = {ps1_value[31], ps1_value};
                op_b = {ps2_value[31], ps2_value};
            end

            // DIVU - Unsigned 32-bit division
            1'b1: begin
                op_a = {1'b0, ps1_value};
                op_b = {1'b0, ps2_value};
            end

            // // REM - Signed 32-bit modulo
            // 2'b10:begin
            //     op_a = {ps1_value[31], ps1_value};
            //     op_b = {ps2_value[31], ps2_value};;
            // end
            
            // // REMU - Unsigned 32-bit modulo
            // 2'b11: begin
            //     op_a = {1'b0, ps1_value};
            //     op_b = {1'b0, ps2_value};
            // end
           
        endcase
    end
end

// Divider IP
DW_div_seq #(   .a_width(33), 
                .b_width(33),
                .tc_mode(1),
                .num_cyc(NUM_STAGES),
                .rst_mode(1),
                .input_mode(1),
                .output_mode(1),
                .early_start(1))
            div_ip (
                .clk(clk),
                .rst_n(!rst),
                .hold('0),
                .start(res_station_select_from_RS),
                .a(op_a),
                .b(op_b),
                .complete(div_is_done),//div_queue_is_full_to_CDB), // When the division is done, then mark the output as full
                .quotient(quotient),
                .remainder(remainder),
                .divide_by_0(divide_by_zero)
            );

// Output datapath
always_comb begin
    div_to_cdb_arb = '0;
    div_is_ready_to_RS = '0; 
    div_queue_result_value = '0;

    if(!rst) begin
        unique case(state)
            busy: begin
                div_to_cdb_arb = shadow_input.data;
                div_is_ready_to_RS = '0;
            end
            not_busy: begin
                div_to_cdb_arb = '0;
                div_is_ready_to_RS = '1;            
            end
            // reset: begin
            default: begin
                div_to_cdb_arb = '0;
                div_is_ready_to_RS = '0;            
            end
        endcase

        unique case(shadow_input.data.funct3[1:0])
            // DIV - Signed 32-bit division
            2'b00: begin
                div_queue_result_value = divide_by_zero ? '1 : quotient[31:0];
                div_queue_result_value = shadow_overflow_flag ? 32'h80000000 : div_queue_result_value;
            end

            // DIVU - Unsigned 32-bit division
            2'b01: begin
                div_queue_result_value = divide_by_zero ? '1 : quotient[31:0];
            end

            // REM - Signed 32-bit modulo
            2'b10:begin
                div_queue_result_value = remainder[31:0];
                div_queue_result_value = shadow_overflow_flag ? 0 : div_queue_result_value;
            end
            
            // REMU - Unsigned 32-bit modulo
            2'b11: begin
                div_queue_result_value = remainder[31:0];
            end
        endcase
    end

    div_queue_result                = '0;
    div_queue_result.rd             = shadow_input.data.rd;
    div_queue_result.pd             = shadow_input.data.pd;
    div_queue_result.valid          = shadow_input.data.valid;
    div_queue_result.rob_entry_idx  = shadow_input.data.rob_entry_idx;
    div_queue_result.rs1_value      = shadow_input.ps1_value_shadow;
    div_queue_result.rs2_value      = shadow_input.ps2_value_shadow;
    div_queue_result.value          = div_queue_result_value;
    div_queue_result.pc            = shadow_input.data.pc;
    div_queue_result.calculated_pc_next = shadow_input.data.pc + 32'd4;
    div_queue_result.opcode        = rs_to_div.opcode;
    div_queue_result.mem_addr      = '0;
    div_queue_result.mem_rmask     = '0;
    div_queue_result.mem_wmask     = '0;
    div_queue_result.mem_rdata     = '0;
    div_queue_result.mem_wdata     = '0;
end


endmodule : divider_exec;








