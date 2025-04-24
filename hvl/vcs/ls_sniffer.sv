module ls_sniffer import rv32i_types::*; (
    input logic clk, rst
);

dispatch_to_lsq_t queue [ST_Q_ENTRIES];

struct packed {
    dispatch_to_lsq_t dispatch_to_lsq;
    logic occupied_entry;
    logic [ST_Q_ENTRIES - 1: 0] st_mask;
    logic [$clog2(LD_RS_ENTRIES) - 1: 0] rel_order;
} rs [LD_RS_ENTRIES];

logic [29:0] staddr, ldaddr;
logic [3:0] stmask, ldmask;

int num_matching_addr_in_store_and_load, num_cycles_with_a_load_a_store;

int num_cycles_with_atleast_1_match;
int num_cycles;
int load_size;
int store_size;

assign queue = $root.top_tb.dut.s_q.queue;
assign rs = $root.top_tb.dut.ld_rs.rs;

logic has_match_in_store;

always_comb begin
    num_matching_addr_in_store_and_load = 0;
    store_size = 0;
    load_size = 0;
    for(int j = 0; j < LD_RS_ENTRIES; j++) begin
        has_match_in_store = '0;
        load_size += rs[j].occupied_entry ? 1 : 0;
        for(int i = 0; i < ST_Q_ENTRIES; i++) begin
            store_size += queue[i].valid ? 1 : 0; 
            if(queue[i].valid && rs[j].occupied_entry) begin
                if(queue[i].ps1_valid && rs[j].dispatch_to_lsq.ps1_valid) begin
                    staddr = queue[i].imm[31:2];
                    ldaddr = rs[j].dispatch_to_lsq.imm[31:2];

                    unique case(queue[i].funct3)
                        3'b000: stmask = 4'b0001 << queue[i].imm[1:0]; // SB
                        3'b001: stmask = 4'b0011 << queue[i].imm[1:0];// SH
                        3'b010: stmask = 4'b1111; // SW
                        default: stmask = 4'b0000; // SW
                    endcase

                    case(rs[j].dispatch_to_lsq.funct3)
                        3'b000, 3'b100 : ldmask = 4'b0001 << rs[j].dispatch_to_lsq.imm[1:0]; // LB, LBU  
                        3'b001, 3'b101 : ldmask = 4'b0011 << rs[j].dispatch_to_lsq.imm[1:0]; // LH, LHU
                        default : ldmask = 4'b1111; //3'b010 :          // LW
                    endcase

                    if(staddr == ldaddr && ((stmask & ldmask) == ldmask)) begin
                        has_match_in_store = '1;
                        //$display("%h %h", queue[i].imm[31:0], rs[j].dispatch_to_lsq.imm[31:0]);
                    end
                end
            end
        end
        num_matching_addr_in_store_and_load += has_match_in_store ? 1 : 0;
    end
    //$display("----");
end

always_ff @ (posedge clk) begin
    if(rst) begin
        num_cycles <= 0;
        num_cycles_with_atleast_1_match <= 0;
        num_cycles_with_a_load_a_store <= 0;
    end else begin
        if(num_matching_addr_in_store_and_load > 0)
            num_cycles_with_atleast_1_match <= num_cycles_with_atleast_1_match + 1;
        if(store_size > 0 && load_size > 0)
            num_cycles_with_a_load_a_store <= num_cycles_with_a_load_a_store + 1;
        num_cycles <= num_cycles + 1;
    end
end

final begin
    $display("Load Store Sniffer: Num_Cycles: %d", num_cycles);
    $display("Load Store Sniffer: Num_Cycles_with_store_load_both_not_empty: %d", num_cycles_with_a_load_a_store);
    $display("Load Store Sniffer: Num_Cycles_with_atleast_1_match: %d", num_cycles_with_atleast_1_match);
end

endmodule;
