// This unit will handle loads and store instructions

// Specifically it handles communications between the LSQ, CDB Arbiter, D-Cache

// NOTE: This doesn't support LUI

// NOTE: This will make RVFI output 0 in case of stores

//      Instr       |      Description(Copying Riscv Spec)         |    Reg Used     |
//------------------|----------------------------------------------|-----------------|
// LB                   8-bit, sign-extended                            M[rs1 + imm] -> rd
//------------------|----------------------------------------------|-----------------|
// LH                   16-bit, sign-extended                           M[rs1 + imm] -> rd
//------------------|----------------------------------------------|-----------------|
// LW                   32-bit                                          M[rs1 + imm] -> rd
//------------------|----------------------------------------------|-----------------|
// LBU                  8-bit, unsigned                                 M[rs1 + imm] -> rd
//------------------|----------------------------------------------|-----------------|
// LHU                  16-bit, unsigned                                M[rs1 + imm] -> rd
//------------------|----------------------------------------------|-----------------|
// SB                   8 lsb                                           rs2 -> M[rs1]
//------------------|----------------------------------------------|-----------------|
// SH                   16 lsb                                          rs2 -> M[rs1]
//------------------|----------------------------------------------|-----------------|
// SW                   32                                              rs2 -> M[rs1]
//------------------|----------------------------------------------|-----------------|

module lsq_adder import rv32i_types::*; #(parameter NUM_SB_ENTRIES = 4) (
    input   logic                   clk, rst, stall, store_allowed, branch_mispredict,
    
    // adder <-> lsq
    input   lsq_entry_t             from_st_q, from_ld_rs,
    output  logic                   st_q_dequeue, ld_rs_dequeue,

    // adder <- register file
    input   logic [31:0]            ps1_s_q_value, ps2_s_q_value, ps1_ld_q_value, //ps2_ld_q_value,
    
    // adder <-> D-Cache
    output   logic   [31:0]  ufp_addr,
    output   logic   [3:0]   ufp_rmask,
    output   logic   [3:0]   ufp_wmask,
    input    logic   [31:0]  ufp_rdata,
    output   logic   [31:0]  ufp_wdata,
    input    logic           ufp_resp,

    // adder <-> CDB Arbiter
    input   logic                   cdb_arb_dequeue,
    output  cdb_entry_t             to_cdb_arb,
    output  logic                   is_full
);

struct packed{
    logic [31:2] addr;
    logic [31:0] data;
    logic [3:0] valid;
} sb [NUM_SB_ENTRIES], sb_next [NUM_SB_ENTRIES];

logic[$clog2(NUM_SB_ENTRIES) - 1 : 0] remove_index, remove_index_next;

// Glue Logic
lsq_entry_t             from_lsq;
logic                   load_store_dequeue;
logic [31:0]            ps1_value, ps2_value;
enum logic {ST_Q, LD_RS} struct_chosen;

always_comb begin
    if(from_st_q.valid && store_allowed) begin
        from_lsq = from_st_q;
        ps1_value = ps1_s_q_value;
        ps2_value = ps2_s_q_value;
        struct_chosen = ST_Q;
    end else begin
        from_lsq = from_ld_rs;
        ps1_value = ps1_ld_q_value;
        ps2_value = '0;//ps2_ld_q_value;
        struct_chosen = LD_RS;
    end
end

always_comb begin
    if(struct_chosen == ST_Q) begin
        st_q_dequeue = load_store_dequeue;
        ld_rs_dequeue = '0;
    end else begin
        st_q_dequeue = '0;
        ld_rs_dequeue = load_store_dequeue;
    end
end

enum logic [1:0] {
    NOT_BUSY = 2'b01,
    WAIT,
    DONE
} status_next, status_reg;

struct packed{
    logic [31:0] ps1_value, ps2_value;
    cdb_entry_t to_cdb_arb;
    logic is_store;
    logic [2:0] funct3;
    logic [3:0] actual_load_mask;
} shadow_next, shadow_reg ;


logic br_en_reg;

// Next state
always_ff @ (posedge clk) begin
    status_reg <= status_next;
    shadow_reg <= shadow_next;
    remove_index <= remove_index_next;

    for(int i = 0; i < NUM_SB_ENTRIES; i++) begin
        if(rst) begin
            sb[i].valid <= '0;
        end else begin
            sb[i] <= sb_next[i];
        end
    end

    if (rst) begin
        br_en_reg <='0;
        remove_index <= '0;
    end
    if (branch_mispredict && (status_reg == WAIT || status_next == WAIT || status_reg == DONE || status_next == DONE)) begin
        br_en_reg <= '1;
    end

    if(status_reg == DONE && status_next == NOT_BUSY && br_en_reg)
        br_en_reg <= '0;
end

// State_value
always_comb begin
    // Default values
    shadow_next = shadow_reg;
    status_next = status_reg;
    remove_index_next = remove_index;

    for(int i = 0; i < NUM_SB_ENTRIES; i++) begin
        sb_next[i] = sb[i];
    end
    
    ufp_addr = 'x;
    ufp_rmask = '0;
    ufp_wmask = '0;
    ufp_wdata = 'x;
    to_cdb_arb = '0;
    is_full = '0;
    load_store_dequeue = '0;

    if(!rst) begin
        unique case (status_reg)

            NOT_BUSY: begin
                // (1) Check for valid load/store
                if(from_lsq.valid && !branch_mispredict) begin

                    shadow_next.ps1_value = ps1_value;
                    shadow_next.ps2_value = ps2_value;

                    shadow_next.to_cdb_arb.rd = from_lsq.data.rd;
                    shadow_next.to_cdb_arb.pd = from_lsq.data.pd;
                    shadow_next.to_cdb_arb.valid = from_lsq.data.valid;
                    shadow_next.to_cdb_arb.rob_entry_idx = from_lsq.data.rob_entry_idx;
                    shadow_next.to_cdb_arb.rs1_value = ps1_value;
                    shadow_next.to_cdb_arb.rs2_value = ps2_value;
                    shadow_next.to_cdb_arb.mem_addr = from_lsq.data.imm;
                    shadow_next.to_cdb_arb.calculated_pc_next = from_lsq.data.pc + 32'd4;
                    shadow_next.to_cdb_arb.opcode = from_lsq.data.opcode;

                    ufp_addr = {shadow_next.to_cdb_arb.mem_addr[31:2], 2'b00};
                    
                    // (2) Aptly setup the mask and wdata values
                    if(from_lsq.data.opcode == op_b_store) begin // Stores
                        if(store_allowed) begin
                            status_next = WAIT;
                            load_store_dequeue = '1;
                            shadow_next.is_store = '1;
                            shadow_next.funct3 = from_lsq.data.funct3;
                            unique case(from_lsq.data.funct3)
                                3'b000: begin // SB
                                        ufp_wmask = 4'b0001 << shadow_next.to_cdb_arb.mem_addr[1:0]; 
                                        ufp_wdata = ps2_value << 8 * shadow_next.to_cdb_arb.mem_addr[1:0];
                                        end
                                3'b001: begin // SH
                                        ufp_wmask = 4'b0011 << shadow_next.to_cdb_arb.mem_addr[1:0];
                                        ufp_wdata = ps2_value << 8 * shadow_next.to_cdb_arb.mem_addr[1:0];
                                        end
                                3'b010: begin // SW
                                        ufp_wmask = 4'b1111;
                                        ufp_wdata = ps2_value;
                                        end
                                default: begin // SW
                                        ufp_wmask = 4'b0000;
                                        ufp_wdata = 32'hxBAD128;
                                        end
                            endcase
                            // Check for SB Hit, if so write into it
                            for(int i = 0; i < NUM_SB_ENTRIES; i++) begin
                                if(sb[i].valid != '0 && sb[i].addr == shadow_next.to_cdb_arb.mem_addr[31:2]) begin
                                    sb_next[i].valid = sb[i].valid | ufp_wmask;
                                    if(ufp_wmask[0])    sb_next[i].data[7 : 0] = ufp_wdata[7 : 0];
                                    if(ufp_wmask[1])    sb_next[i].data[15 : 8] = ufp_wdata[15 : 8];
                                    if(ufp_wmask[2])    sb_next[i].data[23 : 16] = ufp_wdata[23 : 16];
                                    if(ufp_wmask[3])    sb_next[i].data[31 : 24] = ufp_wdata[31 : 24];
                                    shadow_next.to_cdb_arb.mem_rmask = ufp_rmask;
                                    shadow_next.to_cdb_arb.mem_wmask = ufp_wmask;
                                    shadow_next.to_cdb_arb.mem_rdata = '0;
                                    shadow_next.to_cdb_arb.mem_wdata = ufp_wdata;
                                    shadow_next.to_cdb_arb.value = '0;
                                    ufp_wmask = '0;
                                    ufp_wdata = 'hBBADD191;
                                    status_next = DONE;
                                    break;
                                end
                            end
                            // Else write into SB and evict what is there already
                            if(status_next != DONE) begin
                                sb_next[remove_index].addr = shadow_next.to_cdb_arb.mem_addr[31:2];//ufp_addr[31:2];
                                sb_next[remove_index].valid = ufp_wmask;
                                sb_next[remove_index].data = ufp_wdata;

                                shadow_next.to_cdb_arb.mem_rmask = ufp_rmask;
                                shadow_next.to_cdb_arb.mem_wmask = ufp_wmask;
                                shadow_next.to_cdb_arb.mem_rdata = '0;
                                shadow_next.to_cdb_arb.mem_wdata = ufp_wdata;
                                shadow_next.to_cdb_arb.value = '0;

                                remove_index_next = remove_index + ($clog2(NUM_SB_ENTRIES))'(1);

                                if(sb[remove_index].valid != '0) begin
                                    ufp_addr = {sb[remove_index].addr, 2'b00};
                                    ufp_wmask = sb[remove_index].valid;
                                    ufp_wdata = sb[remove_index].data;
                                    status_next = WAIT;
                                end else begin
                                    ufp_addr = '0;
                                    ufp_wmask = '0;
                                    ufp_wdata = '0;
                                    status_next = DONE;
                                end
                            end
            
                        end
                    end else begin // Loads
                        status_next = WAIT;
                        shadow_next.is_store = '0;
                        shadow_next.to_cdb_arb.mem_wmask = '0;
                        shadow_next.to_cdb_arb.mem_wdata = '0;
                        shadow_next.funct3 = from_lsq.data.funct3;
                        load_store_dequeue = '1;
                        case(from_lsq.data.funct3)
                            3'b000, 3'b100 :  // LB, LBU   
                                        ufp_rmask = 4'b0001 << shadow_next.to_cdb_arb.mem_addr[1:0]; 
                            3'b001, 3'b101 :  // LH, LHU  
                                        ufp_rmask = 4'b0011 << shadow_next.to_cdb_arb.mem_addr[1:0];
                            default : //3'b010 :          // LW
                                        ufp_rmask = 4'b1111;
                        endcase

                        shadow_next.actual_load_mask = ufp_rmask;
                        shadow_next.to_cdb_arb.mem_rmask = ufp_rmask;

                        for(int i = 0; i < NUM_SB_ENTRIES; i++) begin
                            if(sb[i].valid != '0 && sb[i].addr == shadow_next.to_cdb_arb.mem_addr[31:2]) begin
                                shadow_next.actual_load_mask = (~sb[i].valid) & ufp_rmask;
                                if(sb[i].valid[0] & ufp_rmask[0]) shadow_next.to_cdb_arb.mem_rdata[7 : 0]  = sb[i].data[7 : 0];
                                if(sb[i].valid[1] & ufp_rmask[1]) shadow_next.to_cdb_arb.mem_rdata[15: 8]  = sb[i].data[15: 8];
                                if(sb[i].valid[2] & ufp_rmask[2]) shadow_next.to_cdb_arb.mem_rdata[23 : 16] = sb[i].data[23 : 16];
                                if(sb[i].valid[3] & ufp_rmask[3]) shadow_next.to_cdb_arb.mem_rdata[31 : 24] = sb[i].data[31 : 24];
                                ufp_wmask = '0;
                                ufp_wdata = 32'hBBADD191;
                                break;
                            end
                        end

                        if(shadow_next.actual_load_mask == '0) begin
                            status_next = DONE;
                            ufp_addr = '0;
                            ufp_wmask = '0;
                            ufp_rmask = '0;
                            ufp_wdata = '0;

                            case(shadow_next.funct3)
                                3'b000:  begin  // LB
                                    shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (8 * shadow_next.to_cdb_arb.mem_addr[1:0]);
                                    shadow_next.to_cdb_arb.value = {{24{shadow_next.to_cdb_arb.value[7]}}, shadow_next.to_cdb_arb.value[7:0]}; 
                                end
                                3'b100 : begin  // LBU
                                    shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (8 * shadow_next.to_cdb_arb.mem_addr[1:0]);
                                    shadow_next.to_cdb_arb.value = {24'b0, shadow_next.to_cdb_arb.value[7:0]};
                                end
                                3'b001:  begin  // LH  
                                    shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (16 * shadow_next.to_cdb_arb.mem_addr[1]);
                                    shadow_next.to_cdb_arb.value = {{16{shadow_next.to_cdb_arb.value[15]}}, shadow_next.to_cdb_arb.value[15:0]}; 
                                end
                                3'b101 : begin  // LHU
                                    shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (16 * shadow_next.to_cdb_arb.mem_addr[1]);
                                    shadow_next.to_cdb_arb.value = {16'b0, shadow_next.to_cdb_arb.value[15:0]}; 
                                end
                                default :   //3'b010 :  // LW
                                    shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata;
                            endcase
                        end
                    end

                    //shadow_next.to_cdb_arb.mem_rmask = ufp_rmask;
                    //shadow_next.to_cdb_arb.mem_wmask = ufp_wmask;
                    //shadow_next.to_cdb_arb.mem_rdata = 32'hXXXXX130;
                    //shadow_next.to_cdb_arb.mem_wdata = ufp_wdata;
                end
            end

            WAIT: begin
                if(ufp_resp) begin
                    status_next = DONE;
                    if(shadow_reg.is_store) begin// store
                        shadow_next.to_cdb_arb.value = '0;
                        shadow_next.to_cdb_arb.mem_rdata = '0;
                    end else begin                   // load
                        
                        if(shadow_reg.actual_load_mask[0])   shadow_next.to_cdb_arb.mem_rdata[7 : 0] = ufp_rdata[7 : 0];
                        if(shadow_reg.actual_load_mask[1])   shadow_next.to_cdb_arb.mem_rdata[15 : 8] = ufp_rdata[15 : 8];
                        if(shadow_reg.actual_load_mask[2])   shadow_next.to_cdb_arb.mem_rdata[23 : 16] = ufp_rdata[23 : 16];
                        if(shadow_reg.actual_load_mask[3])   shadow_next.to_cdb_arb.mem_rdata[31: 24] = ufp_rdata[31 : 24];
                        case(shadow_reg.funct3)
                            3'b000:  begin  // LB
                                shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (8 * shadow_next.to_cdb_arb.mem_addr[1:0]);
                                shadow_next.to_cdb_arb.value = {{24{shadow_next.to_cdb_arb.value[7]}}, shadow_next.to_cdb_arb.value[7:0]}; 
                            end
                            3'b100 : begin  // LBU
                                shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (8 * shadow_next.to_cdb_arb.mem_addr[1:0]);
                                shadow_next.to_cdb_arb.value = {24'b0, shadow_next.to_cdb_arb.value[7:0]};
                            end
                            3'b001:  begin  // LH  
                                shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (16 * shadow_next.to_cdb_arb.mem_addr[1]);
                                shadow_next.to_cdb_arb.value = {{16{shadow_next.to_cdb_arb.value[15]}}, shadow_next.to_cdb_arb.value[15:0]}; 
                            end
                            3'b101 : begin  // LHU
                                shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata >> (16 * shadow_next.to_cdb_arb.mem_addr[1]);
                                shadow_next.to_cdb_arb.value = {16'b0, shadow_next.to_cdb_arb.value[15:0]}; 
                            end
                            default :   //3'b010 :  // LW
                                shadow_next.to_cdb_arb.value = shadow_next.to_cdb_arb.mem_rdata;
                        endcase
                    end

                end

                //shadow_next.to_cdb_arb.mem_rdata = ufp_rdata;
            end

            default: begin//DONE: begin
                if(!br_en_reg) begin
                    to_cdb_arb = shadow_reg.to_cdb_arb;
                    is_full = '1;

                    if(cdb_arb_dequeue)
                        status_next = NOT_BUSY;
                end else if (br_en_reg) begin
                    status_next = NOT_BUSY;
                end
            end

        endcase;
    end else begin
        shadow_next = '0;
        status_next = NOT_BUSY;
    end

    // Not sure if this stall logic will work
    if(stall) begin
        shadow_next = shadow_reg;
        shadow_next = shadow_reg;
    end
end


endmodule
