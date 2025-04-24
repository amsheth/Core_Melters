package mem_types;

    localparam NUM_SETS = 32;
    localparam NUM_ISETS= 32;
    typedef struct packed {  
        logic [(31-($clog2(NUM_SETS)+5)):00] tag;
        logic [($clog2(NUM_SETS)-1):00] set_addr;
        logic [04:00] offset;
        logic   [31:0]  ufp_addr;
        logic   [3:0]   ufp_rmask;
        logic   [3:0]   ufp_wmask;
        logic   [31:0]  ufp_wdata;
    } cache_t;

    typedef struct packed {  
        logic [(31-($clog2(NUM_ISETS)+5)):00] tag;
        logic [($clog2(NUM_ISETS)-1):00] set_addr;
        logic [04:00] offset;
        logic   [31:0]  ufp_addr;
        logic   [3:0]   ufp_rmask;
        logic   [3:0]   ufp_wmask;
        logic   [31:0]  ufp_wdata;
    } icache_t;


endpackage : mem_types


package rv32i_types;

    localparam NUM_ARCH_REG = 32;
    localparam NUM_ROB_ENTRIES = 8;
    localparam NUM_PHYS_REG = NUM_ROB_ENTRIES+ 32;
    localparam PHYS_REG_IDX = $clog2(NUM_PHYS_REG) - 1;
    localparam ARCH_REG_IDX = $clog2(NUM_ARCH_REG) - 1;
    localparam NUM_RS_ENTRIES = 2;

    localparam ST_Q_ENTRIES = 2; // Can be any value >= 1
    localparam LD_RS_ENTRIES = 2; // Can be any value >= 1
    localparam BRANCH_PRED_M = 1;
    localparam NUM_ORDER = 10;

    typedef struct packed {
        logic valid;
        logic [63:0] order;
        logic [31:0] inst;
        logic [ARCH_REG_IDX:0] rs1_addr, rs2_addr, rd_addr;
        logic [31:0] rs1_rdata, rs2_rdata, rd_wdata;
        // logic [PHYS_REG_IDX:0] frd_addr;
        // logic [31:0] frd_wdata;
        logic [31:0] pc_rdata;
        logic [31:0] pc_wdata;
        logic [31:0] mem_addr;
        logic [3:0] mem_rmask;
        logic [3:0] mem_wmask;
        logic [31:0] mem_rdata;
        logic [31:0] mem_wdata;
    } rvfi_t;

    typedef struct packed {
        logic [ARCH_REG_IDX:0] rd;
        logic [PHYS_REG_IDX:0] pd;
        logic valid;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] rs1_value, rs2_value, value;
        logic [6:0]  opcode;
        logic [31:0] pc;
        logic [31:0] calculated_pc_next;
        logic [31:0] mem_addr;
        logic [3:0]  mem_rmask;
        logic [3:0]  mem_wmask;
        logic [31:0]  mem_rdata;
        logic [31:0]  mem_wdata;
    } cdb_entry_t; 

    typedef struct packed {
        logic   [31:0]  inst; // Value sent to ROB
        logic   [31:0]  pc;
        logic   [31:0]  pc_next; // Values sent to ROB
        //logic   [63:0]  mul_opsorder;
        logic           valid; //commit;

        logic   [PHYS_REG_IDX:0]   ps1_s, ps2_s, pd_s;
        logic   [ARCH_REG_IDX:0]  rd_s, rs1_s, rs2_s;
        logic   ps1_valid, ps2_valid;
        logic   [2:0]   funct3;
        logic   [6:0]   funct7;
        logic   [6:0]   opcode;
        logic   [31:0]  imm;
        logic   [63:0]  order;
        logic   [BRANCH_PRED_M - 1:0]   br_hist;

        //    logic   [02:0]  aluop;
        //    logic   [02:0]  cmpop;
        logic           regf_we;
       // alu_m1_sel_t        alu_m1_sel;
    } decode_rename_to_dispatch_t; // Decode & Rename -> Pipeline Reg(Initially, no pipeline reg) -> Dispatch

    typedef struct packed {
        logic [PHYS_REG_IDX:0] pd;
        logic [ARCH_REG_IDX:0] rs1, rs2, rd;
        logic           write_en; //commit;
    } decode_rename_to_RAT_t; // decode/renamer sends these values to RAT

    typedef struct packed {
        logic [PHYS_REG_IDX:0] ps1, ps2;
        logic ps1_valid, ps2_valid;
    } RAT_to_decode_rename_t; // RAT sends these values to the decode/renamer

    typedef struct packed {
        logic [ARCH_REG_IDX:0] rd;
        logic [PHYS_REG_IDX:0] pd;
        logic [31:0] pc;
        logic [31:0] pc_next;
        logic [63:0] order;
        logic [6:0] opcode;
        logic [31:0] calculated_pc_next;
        logic   [BRANCH_PRED_M - 1:0]   br_hist;
    } dispatch_to_ROB_only_data_t; // Dispatch sends these values to the RoB to create a new entry

    typedef struct packed {
        dispatch_to_ROB_only_data_t dispatch_to_ROB_only_data; // Can this be renamed to hold only the data
        rvfi_t rvfi;
        logic enqueue_rob;
    } dispatch_to_ROB_t;

    typedef struct packed {
        logic commit;
        // logic flush;
        dispatch_to_ROB_only_data_t dispatch_data;
        rvfi_t rvfi;
    } ROB_entry_t;

    typedef struct packed {
        logic [($clog2(NUM_ROB_ENTRIES)-1):0] rob_entry_idx;
        logic is_rob_full;
    } ROB_to_dispatch_t; // RoB sends these values to the dispatch

    typedef struct packed {
        ROB_entry_t rob_entry;
        logic is_rob_empty;
    } ROB_to_RRF_t;

    typedef struct packed {
        logic dequeue;
    } RRF_to_ROB_t;

    // TODO: struct that passes dispatch to RS
    typedef struct packed {
        logic ps1_valid, ps2_valid;
        logic [PHYS_REG_IDX:0] ps1, ps2, pd;
        logic [ARCH_REG_IDX:0] rd;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [6:0] opcode;
        logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } dispatch_to_rs_t;

    // Struct that passes from dispatch to the LSQ
    typedef struct packed {
        logic ps1_valid, ps2_valid;
        logic [PHYS_REG_IDX:0] ps1, ps2, pd;
        logic [ARCH_REG_IDX:0] rd;
        logic [2:0] funct3;
        // logic [6:0] funct7;
        logic [6:0] opcode;
        logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } dispatch_to_lsq_t;

    typedef struct packed {
        // TODO: finish this up
        // PR[rs1], PR[rs2], RD, funct7, funct3, valid
        logic ps1_valid, ps2_valid;
        logic [PHYS_REG_IDX:0] ps1, ps2, pd;
        logic [ARCH_REG_IDX:0] rd;
        // logic [31:0] ps1_value, ps2_value;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [6:0] opcode;
        logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } rs_to_alu_t;

       typedef struct packed {
        // TODO: finish this up
        // PR[rs1], PR[rs2], RD, funct7, funct3, valid
        logic ps1_valid, ps2_valid;
        logic [PHYS_REG_IDX:0] ps1, ps2, pd;
        logic [ARCH_REG_IDX:0] rd;
        // logic [31:0] ps1_value, ps2_value;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [6:0] opcode;
        logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } rs_to_br_t;

    typedef struct packed {
        // TODO: finish this up
        // PR[rs1], PR[rs2], RD, funct7, funct3, valid
        logic ps1_valid, ps2_valid;
        logic [PHYS_REG_IDX:0] ps1, ps2, pd;
        logic [ARCH_REG_IDX:0] rd;
        // logic [31:0] ps1_value, ps2_value;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [6:0] opcode;
        logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } rs_to_mult_t;

    typedef struct packed {
        // TODO: finish this up
        // PR[rs1], PR[rs2], RD, funct7, funct3, valid
        logic ps1_valid, ps2_valid;
        logic [PHYS_REG_IDX:0] ps1, ps2, pd;
        logic [ARCH_REG_IDX:0] rd;
        // logic [31:0] ps1_value, ps2_value;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [6:0] opcode;
        logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } rs_to_div_t;

    typedef struct packed {
        logic [PHYS_REG_IDX:0] pd;
        logic [ARCH_REG_IDX:0] rd;
        logic [2:0] funct3;
        // logic [6:0] funct7;
        logic [6:0] opcode;
        // logic [31:0] imm;
        logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_entry_idx;
        logic [31:0] pc;
        logic valid;
    } mult_pipe_t;

    typedef struct packed {
        rs_to_alu_t data;
        logic [NUM_ORDER:0] order;
    } ALU_RS_entry_t;

    typedef struct packed {
        rs_to_alu_t data;
        logic [NUM_ORDER:0] order;
    } MUL_RS_entry_t;

    typedef struct packed {
        rs_to_br_t data;
        logic [NUM_ORDER:0] order;
    } BR_RS_entry_t;

    typedef struct packed {
        dispatch_to_lsq_t data;
        logic valid;
    } lsq_entry_t;

    typedef struct packed {
       logic   [31:0]  inst;
       logic   [31:0]  pc;
       logic   [31:0]  pc_next;
       logic   [63:0]  order;
       logic           valid; //commit;
    } fetch_to_queue; //fetch -> fetch queue -> Decode & Rename

    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;
    typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000,
        mult           = 7'b0000001
    } funct7_t;


    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] { 
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
        // branch_f3_not  = 
    } branch_f3_t;

    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

    typedef enum logic [2:0] {
        mul_op_mul      = 3'b000,
        mul_op_mulh     = 3'b001,
        mul_op_mulhsu   = 3'b010,
        mul_op_mulhu    = 3'b011,
        mul_op_div      = 3'b100,
        mul_op_divu     = 3'b101,
        mul_op_rem      = 3'b110,
        mul_op_remu     = 3'b111
    } mul_ops;

    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;


        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

    } instr_t;

    // add your types in this file if needed.

endpackage : rv32i_types

