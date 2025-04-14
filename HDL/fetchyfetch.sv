module fetchyfetch
import rv32i_types::*;
#(
    parameter TL=0
)
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
    input logic [BRANCH_PRED_M - 1:0] br_update_hist,

    input  logic [31:0]   ufp_rdata,
    output logic [31:0] ufp_addr,
    output logic [31:0] pc,
    output logic [31:0] pc_n,
    output logic [3:0] ufp_rmask,
    output logic [63:0] order_reg,
    output logic br_en_reg,
    output logic [BRANCH_PRED_M - 1:0] br_hist_out
);

logic [31:0] pc_reg, pc_next,next,inst,brt;
logic is_pending_mem_request_reg, is_pending_mem_request_next;
logic [63:0] order_next;
// logic br_en_reg;

//RAS
bit push,pop,empty;
logic [31:0] ras_jal,ras_jalr;

logic link_rd;
logic link_rs;


// Branch prediction Values
localparam M = (TL)? BRANCH_PRED_M : 1;
localparam N = 2;
localparam NUM_ENTRIES = 512;

// Branch prediction output
logic branch_predicted_taken;

// Internal Signals:
logic valid_out, valid_out_2;
logic br_hist_update;

// Branch prediction registers
enum logic [1:0] {read_default_output=2'b01, write_taken, write_not_taken} branch_table_state,
                                    branch_table_state_next;
logic [NUM_ENTRIES - 1 : 0]      valid;
logic [M - 1 : 0]                   br_hist, br_hist_next;
// logic [M : 0]                   br_hist, br_hist_next;

//  generate
//         if (TL == 0) begin
//             // Logic generator 1
//             always_comb begin
//                 out = a & b; // AND logic
//             end
//         end else begin
//             // Logic generator 2
//             always_comb begin
//                 out = a | b; // OR logic
//             end
//         end
// endgenerate
// Connections to output
assign br_hist_out = br_hist_update ? br_hist_next : br_hist; 

// SRAM Inputs
logic   [$clog2(NUM_ENTRIES) - 1 : 0]       table_addr, table_addr_2, last_table_addr;
logic                               table_web;
logic   [N - 1 : 0]                         table_in;

// SRAM Outputs
logic   [N - 1 : 0]                         table_out, table_out_2;

// SRAM
mp_ooo_2_port_512_entry_2_bit branch_table (  .clk0(clk),
                                    .csb0('0),
                                    .web0(table_web),
                                    .addr0(table_addr),
                                    .din0(table_in),
                                    .dout0(table_out),
                                    .clk1(clk),
                                    .csb1('0),
                                    .web1('1),
                                    .addr1(table_addr_2),
                                    .din1('x),
                                    .dout1(table_out_2));

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
assign ras_jal={{12{ufp_rdata[31]}}, ufp_rdata[19:12], ufp_rdata[20], ufp_rdata[30:21], 1'b0};

assign link_rd= (ufp_rdata[11:7]== 5'h01|| ufp_rdata[11:7]== 5'h05);
assign link_rs= (ufp_rdata[19:15]== 5'h01|| ufp_rdata[19:15]== 5'h05);
always_comb begin
    push='0;
    pop='0;
    if (ufp_rdata[6:0]==op_b_jal && link_rd)
        push='1;
    else if (ufp_rdata[6:0]==op_b_jalr && !empty && !link_rd && link_rs)
        pop='1;
    else if (ufp_rdata[6:0]==op_b_jalr && link_rd && !link_rs)
        push='1;
    else if (ufp_rdata[6:0]==op_b_jalr && link_rd && link_rs) begin
        push='1;
        if (ufp_rdata[11:7]!=ufp_rdata[19:15] && !empty)
            pop='1;
    end
    else begin
        push='0;
        pop='0;
    end
end

stack #(.WIDTH(32), .DEPTH(2)) ras(
    .clk,
    .rst,
    .push,
    .pop,
    .data_in(pc_reg+32'h4),
    .data_out(ras_jalr),
    .empty
);


always_comb begin
    if (ufp_rdata[6:0]==op_b_br && ufp_resp && !is_fetch_q_full &&!rst) begin
        if(branch_predicted_taken) begin
            next={{20{ufp_rdata[31]}}, ufp_rdata[7], ufp_rdata[30:25], ufp_rdata[11:8], 1'b0};
            br_hist_next = br_hist << 1;
            br_hist_next[0] =  '1;
            br_hist_update = '1;
            
        end else begin
            next = 32'h4;
            br_hist_next = br_hist << 1;
            br_hist_next[0] =  '0;
            br_hist_update = '1;

        end
    end else begin
        next = 32'h4;
        br_hist_next = 'x;
        br_hist_update = '0;
    end

    if(branch_mispredict) begin
        br_hist_next = br_update_hist;
        br_hist_update = '1;
    end
end

always_comb begin
    order_next =   (branch_mispredict) ? (new_fetch_order + 64'b1) :
                is_fetch_q_full ? order_reg :
                (!is_pending_mem_request_reg) ? (order_reg) : 
                (is_pending_mem_request_reg && ufp_resp && !br_en_reg) ? (order_reg + 64'b1) : order_reg;
    pc_next =   (branch_mispredict) ? (new_fetch_pc) :
                is_fetch_q_full ? pc_reg :
                (!is_pending_mem_request_reg) ? (pc_reg) : 
                (is_pending_mem_request_reg && ufp_resp && (ufp_rdata[6:0]==op_b_jal) && !br_en_reg) ? (pc_reg + ras_jal) :
                (is_pending_mem_request_reg && ufp_resp && pop && !empty && !br_en_reg) ? (ras_jalr) :
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
        valid_out <= '0;
        valid_out_2 <= '0;
    end else begin
        valid_out <= valid[table_addr];
        valid_out_2 <= valid[table_addr_2];
        if(!table_web)
            valid[table_addr] <= '1;
    end
end

// Reset and State Logic
always_ff @ (posedge clk) begin
    if(rst) begin
        br_hist <= '0;
        branch_table_state <= read_default_output;
        last_table_addr <= 'x;
    end else begin
        if(br_hist_update) begin
            br_hist <= br_hist_next;
        end

        branch_table_state <= branch_table_state_next;
        last_table_addr <= table_addr;
    end
end

/*
input logic br_update,
input logic br_taken,
input logic br_pc,
    */

assign branch_predicted_taken = valid_out_2 ? table_out_2[N - 1] : '0;

// Mealy Machine
generate
    if (TL==0) begin
        always_comb begin
            table_in = 'x;

            table_addr_2[0 +: $clog2(NUM_ENTRIES)] = ufp_addr[2 +: $clog2(NUM_ENTRIES)];
            // if (TL!=0) begin
            //     table_addr_2[$clog2(NUM_ENTRIES) - 1: $clog2(NUM_ENTRIES) - M] = br_hist_update ? br_hist_next : br_hist;
            //     table_addr[$clog2(NUM_ENTRIES) - 1: $clog2(NUM_ENTRIES) - M] = br_hist_update ? br_hist_next : br_hist;
            // end

            unique case(branch_table_state)
                write_taken:
                    begin
                        table_addr = last_table_addr;
                        branch_table_state_next = read_default_output;

                        if(valid_out) begin
                            if(table_out == '1) begin
                                table_web = '1;
                                table_in = 'x;
                            end else begin
                                table_web = '0;
                                table_in = table_out + (N)'(1);
                            end
                        end else begin
                            table_web = '0;
                            table_in = (N)'(1);
                        end
                    end

                write_not_taken:
                    begin
                        table_addr = last_table_addr;
                        branch_table_state_next = read_default_output;

                        if(valid_out) begin
                            if(table_out == '0) begin
                                table_web = '1;
                                table_in = 'x;
                            end else begin
                                table_web = '0;
                                table_in = table_out - (N)'(1);
                            end
                        end else begin
                            table_web = '0;
                            table_in = '0;
                        end
                    end
                
                default://read_default_output:
                    begin
                        if(br_update) begin
                            table_addr[0 +: $clog2(NUM_ENTRIES)] = br_pc[2 +: $clog2(NUM_ENTRIES)];
                            branch_table_state_next = br_taken ? write_taken : write_not_taken;
                            table_web = '1;
                        end else begin
                            table_addr = 'x; //last_table_addr;
                            branch_table_state_next = read_default_output;
                            table_web = '1;
                        end
                    end

            endcase
        end
    end
    else begin
            always_comb begin
            table_in = 'x;

            table_addr_2[0 +: $clog2(NUM_ENTRIES) - M] = ufp_addr[2 +: $clog2(NUM_ENTRIES) - M];
            table_addr_2[$clog2(NUM_ENTRIES) - 1: $clog2(NUM_ENTRIES) - M] = br_hist_update ? br_hist_next : br_hist;
            table_addr[$clog2(NUM_ENTRIES) - 1: $clog2(NUM_ENTRIES) - M] = br_hist_update ? br_hist_next : br_hist;

            unique case(branch_table_state)
                write_taken:
                    begin
                        table_addr = last_table_addr;
                        branch_table_state_next = read_default_output;

                        if(valid_out) begin
                            if(table_out == '1) begin
                                table_web = '1;
                                table_in = 'x;
                            end else begin
                                table_web = '0;
                                table_in = table_out + (N)'(1);
                            end
                        end else begin
                            table_web = '0;
                            table_in = (N)'(1);
                        end
                    end

                write_not_taken:
                    begin
                        table_addr = last_table_addr;
                        branch_table_state_next = read_default_output;

                        if(valid_out) begin
                            if(table_out == '0) begin
                                table_web = '1;
                                table_in = 'x;
                            end else begin
                                table_web = '0;
                                table_in = table_out - (N)'(1);
                            end
                        end else begin
                            table_web = '0;
                            table_in = '0;
                        end
                    end
                
                default://read_default_output:
                    begin
                        if(br_update) begin
                            table_addr[0 +: $clog2(NUM_ENTRIES) - M] = br_pc[2 +: $clog2(NUM_ENTRIES) - M];
                            branch_table_state_next = br_taken ? write_taken : write_not_taken;
                            table_web = '1;
                        end else begin
                            table_addr = 'x; //last_table_addr;
                            branch_table_state_next = read_default_output;
                            table_web = '1;
                        end
                    end

            endcase
        end
    end
endgenerate

endmodule
