module ld_rs import rv32i_types::*; #(
                    parameter LENGTH = 4,
                    parameter SQ_LENGTH = 4,
                    parameter NUM_CDB = 2
                  )(
                  input logic                       clk, rst,
                  
                  // LSQ <- CDB
                  input cdb_entry_t                 cdb,
                  input cdb_entry_t                 cdb2,
                  
                  // LSQ <-> dispatch
                  input dispatch_to_lsq_t           dispatch_to_lsq,
                  input logic                       dispatch_stall,
                  output logic                      is_lsq_full,

                  // LSQ <-> LSQ adder
                  input  logic                      lsq_dequeue,
                  input  logic                      sq_dequeued,
                  output lsq_entry_t                lsq_to_adder,

                  // LD RS <-> Regfile
                  output logic [PHYS_REG_IDX : 0]   ps1_s,
                  input logic [31 : 0]    ps1_value,

                  // SQ -> LD RS
                  input dispatch_to_lsq_t          squeue [SQ_LENGTH],
                  input logic [$clog2(SQ_LENGTH) - 1 : 0]     sq_head
                  );

localparam LENGTHEXP = $clog2(LENGTH) - 1;
localparam COUNTEREXP = $clog2(ST_Q_ENTRIES);

struct packed {
    dispatch_to_lsq_t dispatch_to_lsq;
    logic occupied_entry;
    logic [SQ_LENGTH - 1: 0] st_mask;
    logic [LENGTHEXP: 0] rel_order;
} rs [LENGTH];

struct packed {
    logic [LENGTHEXP : 0] value;
    logic valid;
} index;

cdb_entry_t cdb_array[NUM_CDB];
assign cdb_array[0] = cdb;
assign cdb_array[1] = cdb2;

always_ff @ (posedge clk) begin
    if(rst) begin
        for(int i = 0; i < LENGTH; i++) begin
            rs[i] <= 'x;
            rs[i].occupied_entry <= '0;
        end
    end else begin
        for(int i = 0; i < LENGTH; i++) begin
            if(!rs[i].occupied_entry && dispatch_to_lsq.valid && !dispatch_stall) begin
                rs[i].dispatch_to_lsq <= dispatch_to_lsq; 
                if(dispatch_to_lsq.ps1_valid) begin
                    rs[i].dispatch_to_lsq.imm <= dispatch_to_lsq.imm + ps1_value;
                    for(int j = 0; j < NUM_CDB; j++) begin
                        if(cdb_array[j].pd == dispatch_to_lsq.ps1)
                            rs[i].dispatch_to_lsq.imm <= dispatch_to_lsq.imm + cdb_array[j].value;
                    end
                end
                rs[i].occupied_entry <='1;
                rs[i].rel_order <= '0;
                for(int j = 0; j < LENGTH; j++) begin
                    if(rs[j].occupied_entry)
                        rs[j].rel_order <= rs[j].rel_order + 1; 
                end
                for(int j = 0; j < SQ_LENGTH; j++) begin
                    rs[i].st_mask[j] <= squeue[j].valid && ((sq_head == ($clog2(SQ_LENGTH))'(unsigned'(j))) ? !sq_dequeued : '1);
                end
                break;
            end
        end

        for(int j = 0; j < LENGTH; j++) begin
            for(int i = 0; i < NUM_CDB; i++) begin
                if(cdb_array[i].valid) begin
                    if(rs[j].occupied_entry && rs[j].dispatch_to_lsq.ps1 == cdb_array[i].pd) begin// && !rs[j].dispatch_to_lsq.ps1_valid)
                        rs[j].dispatch_to_lsq.ps1_valid <= '1;
                        rs[j].dispatch_to_lsq.imm <= rs[j].dispatch_to_lsq.imm + cdb_array[i].value;
                    end
                end
            end
        end

        for(int i = 0; i < LENGTH; i++) begin
            if(rs[i].occupied_entry) begin
                if(sq_dequeued)
                    rs[i].st_mask[sq_head] <= '0;
                for(int j = 0; j < SQ_LENGTH; j++) begin
                    if(squeue[j].ps1_valid && rs[i].dispatch_to_lsq.ps1_valid && squeue[j].imm[31:2] != rs[i].dispatch_to_lsq.imm[31:2])
                        rs[i].st_mask[j] <= '0;
                end
            end
        end

        if(index.valid && lsq_dequeue) begin
            rs[index.value] <= '0;
            for(int i = 0; i < LENGTH; i++) begin
                if(rs[i].occupied_entry && rs[i].rel_order < rs[index.value].rel_order)
                    rs[i].rel_order <= rs[i].rel_order + 1; 
            end
        end
    end
end

always_comb begin
    lsq_to_adder.data = 'x;
    lsq_to_adder.valid = '0;
    index = '0;
    ps1_s = '0;
    for(int i = 0; i < LENGTH; i++) begin
        if(rs[i].occupied_entry && rs[i].st_mask == '0 && rs[i].dispatch_to_lsq.ps1_valid && (!index.valid || (rs[i].rel_order > rs[index.value].rel_order))) begin
            lsq_to_adder.data = rs[i].dispatch_to_lsq;
            lsq_to_adder.valid = '1;
            index.value = (LENGTHEXP + 1)'(unsigned'(i));
            index.valid = '1;
            ps1_s = rs[i].dispatch_to_lsq.ps1;
        end
    end
end

always_comb begin
    is_lsq_full = '1;
    for(int i = 0; i < LENGTH; i++) begin
        is_lsq_full = is_lsq_full && rs[i].occupied_entry;
    end
end




endmodule;
