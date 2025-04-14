module bmem_controller
import rv32i_types::*;
#(
    parameter NUM_RS = 4
)
(
    input   logic                clk,
    input   logic                rst,

    input   logic               bmem_rvalid,///incoming data valid
    output  logic [31:0]        bmem_addr,
    output  bit                 bmem_read,
    output  logic               bmem_write,
    output  logic [63:0]        bmem_wdata,
    input   logic               bmem_ready,
    input   logic [63:0]        bmem_rdata,
    input   logic [31:0]        bmem_raddr,

    input   logic [31:0]        dcache_addr,
    input   logic               dcache_read,
    input   logic               dcache_write,
    output  logic [255:0]       dcache_rdata,
    input   logic [255:0]       dcache_wdata,
    output  logic               dcache_resp,/////cache_response for cpu
    
    input   logic [31:0]        icache_addr,
    input   logic               icache_read,
    input   logic               icache_write,
    output  logic [255:0]       icache_rdata,
    input   logic [255:0]       icache_wdata,
    output  logic               icache_resp /////cache_response for cpu
);


logic a1;
logic [255:0] a2;

assign a1= icache_write;
assign a2= icache_wdata;

logic [31:0] addr_array[NUM_RS];
logic [255:0]      data[NUM_RS];


logic [1:0] rcount,wcount;
logic wr_done,enqueue;
logic [31:0] mem_addr;
logic mem_read;
logic d_not_in_rs,i_not_in_rs,p_not_in_rs;
logic [255:0] mem_wdata;
logic [31:0] prefetch_addr,remove_prefetch_addr;

logic   [NUM_RS - 1:0]  rs_entry_is_vacant; // Is high when the RS entry is empty
logic   [NUM_RS - 1:0]  rs_ready_to_dispatch;
logic   [NUM_RS - 1:0]  rs_is_prefetched;

logic remove_prefetch, remove_prefetch_later;

logic   [$clog2(NUM_RS)-1:0]       RS_loc;  ////change name   
logic   [$clog2(NUM_RS + 1) -1:0]     remove_rs_for_icache;
logic   [$clog2(NUM_RS + 1) -1:0]     remove_rs_for_dcache;
logic   [$clog2(NUM_RS + 1) -1:0]     remove_rs_for_prefetch;

logic prefetch_done;

logic icache_read_reg;

priority_enc  #(.COUNT(NUM_RS)) priority_enc(.in(rs_entry_is_vacant),.out(RS_loc));


always_comb begin 
// always_ff @( posedge clk ) begin 
    d_not_in_rs = '1;
    for (int i=0; i<NUM_RS; i++) begin
        if (addr_array[i]==dcache_addr) begin
            d_not_in_rs = '0;
            break;
        end
    end
end

always_comb begin 
// always_ff @( posedge clk ) begin 
    i_not_in_rs = '1;
    for (int i=0; i<NUM_RS; i++) begin
        if (addr_array[i]==icache_addr) begin
            i_not_in_rs = '0;
            break;
        end
    end
end

always_comb begin 
// always_ff @( posedge clk ) begin 
    p_not_in_rs = '1;
    for (int i=0; i<NUM_RS; i++) begin
        if (addr_array[i]==prefetch_addr) begin
            p_not_in_rs = '0;
            break;
        end
    end
end


logic [255:0] temp_wdata;

// assign temp_wdata = (bmem_rdata<<64*rcount);
assign temp_wdata = '1;

always_ff @( posedge clk ) begin
    enqueue<='0;
    if (rst) begin
        rcount <= 2'b0;
        mem_addr <= 32'h0;
        mem_wdata <= 256'h0;
    end 
    else if (bmem_rvalid) begin
        rcount <= rcount + 1'b1;
        mem_addr <= bmem_raddr;
        if (rcount=='0)
            mem_wdata <= {192'b0,bmem_rdata};
        else
            mem_wdata <= mem_wdata|(256)'(bmem_rdata<<64*rcount);
        if (rcount == 2'd3)
            enqueue<='1;
    end
end
// end
int a;
assign a=$countones(rs_entry_is_vacant);

// always_comb begin
//     prefetch_done='0;
//     for(int i = 0; i < NUM_RS; i++) begin
//         if (addr_array[i]==prefetch_addr && rs_ready_to_dispatch[i]) begin
//             prefetch_done='1;
//             break;
//         end
//     end
// end

// always_ff @( posedge clk ) begin : blockName
    
// end

always_ff @( posedge clk ) begin : blockName
    icache_read_reg<=icache_read;
end

int miss_times;

always_ff @( posedge clk ) begin
    bmem_addr<='0;
    bmem_read<='0;
    bmem_write<='0;
    bmem_wdata<='0;
    remove_prefetch<='0;
    wr_done<='0;
    if (rst) begin
        prefetch_addr<=32'h1eceb000;
        miss_times<='0;
        remove_prefetch_later<='0;
        wcount <= 2'b0;
        for(int i = 0; i < NUM_RS; i++) begin
            rs_entry_is_vacant[i] <= '1;
            addr_array[i]<='1;
            rs_is_prefetched[i]<='1;
        end
        prefetch_done<='1;
        rs_ready_to_dispatch<='0;
    end
    else begin 
        if (dcache_write && bmem_ready && !wr_done) begin
            // dcache_resp<='0;
            bmem_write<='1;
            bmem_read<='0;
            bmem_addr<=dcache_addr;
            wcount<=wcount+1'b1;
            bmem_wdata<=dcache_wdata[wcount*64+:64];
            if (wcount==3) begin
                wr_done<='1;
            end
        end
        else if (dcache_read && d_not_in_rs && bmem_ready) begin
            // dcache_resp<='0;
            bmem_write<='0;
            bmem_read<='1;
            bmem_addr<=dcache_addr;
            addr_array[RS_loc] <= dcache_addr;
            rs_entry_is_vacant[RS_loc]<='0;
            // rs_is_prefetched[RS_loc]<='0;
        end
        else if (icache_read && i_not_in_rs && bmem_ready) begin
            // icache_resp<='0;
            bmem_write<='0;
            bmem_read<='1;
            bmem_addr<=icache_addr;
            addr_array[RS_loc] <= icache_addr;
            rs_entry_is_vacant[RS_loc]<='0;
            // rs_is_prefetched[RS_loc]<='0;
        end
        else if (p_not_in_rs && bmem_ready && a>2) begin
            bmem_write<='0;
            bmem_read<='1;
            bmem_addr<=prefetch_addr;
            addr_array[RS_loc] <= prefetch_addr;
            rs_entry_is_vacant[RS_loc]<='0;
            prefetch_done<='0;
        end

        if (icache_read && icache_addr == prefetch_addr) begin
            prefetch_addr <= prefetch_addr + 32'h20;
            // if (prefetch_done)
            prefetch_done<='1;
                remove_prefetch<='0;
        end

        else if (icache_read && (icache_addr+32'h20!= prefetch_addr) && !icache_resp) begin
            remove_prefetch_addr<=prefetch_addr;
            prefetch_addr <= icache_addr + 32'h20;
            miss_times<=miss_times+1;
            // if ((icache_addr + 32'h20) != prefetch_addr)
                if (prefetch_done)
                    remove_prefetch<='1;
                else 
                    begin
                        remove_prefetch_later<='1;
                    end
        end
        // else if (p_not_in_rs && prefetch_done && !icache_resp)
        //     prefetch_addr <= prefetch_addr + 32'h20;





        for (int i=0;i<NUM_RS;i++)begin
            if (addr_array[i]==remove_prefetch_addr && remove_prefetch_later && enqueue) begin
                remove_prefetch_later<='0;
                remove_prefetch_addr<='1;
                rs_entry_is_vacant[i]<='1;
                addr_array[i]<='1;
                rs_ready_to_dispatch[i]<='0;
            end
            else if (addr_array[i]==mem_addr && enqueue) begin
                data[i]<=mem_wdata;
                rs_ready_to_dispatch[i]<='1;
                if (addr_array[i]==prefetch_addr) begin
                    prefetch_done<='1;
                end
            end
            //     rs_is_prefetched[i]<='1;
            // if (addr_array[i]==icache_addr || addr_array[i] == dcache_addr) begin
            //     rs_is_prefetched[RS_loc]<='0;
            // end
        end

        if (remove_rs_for_icache != '0) begin
            rs_entry_is_vacant[remove_rs_for_icache-1]<='1;
            addr_array[remove_rs_for_icache-1]<='1;
            rs_ready_to_dispatch[remove_rs_for_icache-1]<='0;
            // rs_is_prefetched[RS_loc]<='1;
        end
        if (remove_rs_for_dcache != '0) begin
            rs_entry_is_vacant[remove_rs_for_dcache-1]<='1;
            addr_array[remove_rs_for_dcache-1]<='1;
            rs_ready_to_dispatch[remove_rs_for_dcache-1]<='0;
            // rs_is_prefetched[RS_loc]<='1;
        end
        if (remove_rs_for_prefetch != '0) begin
            rs_entry_is_vacant[remove_rs_for_prefetch-1]<='1;
            addr_array[remove_rs_for_prefetch-1]<='1;
            rs_ready_to_dispatch[remove_rs_for_prefetch-1]<='0;
            // rs_is_prefetched[RS_loc]<='1;
        end

    end
end

logic [31:0] icache_addr_reg, dcache_addr_reg;

always_ff @( posedge clk ) begin
    icache_addr_reg<=icache_addr;
    dcache_addr_reg<=dcache_addr;
end



always_comb begin
    remove_rs_for_icache   = '0;
    //remove_rs_for_dcache  = '0;
    remove_rs_for_prefetch = '0;
    // (1) Go through each reservation station
    for (int i=0;i<NUM_RS;i++) begin
        if (addr_array[i]==icache_addr_reg && rs_ready_to_dispatch[i] && icache_read && icache_read_reg) begin
            remove_rs_for_icache = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
        end
        else if (addr_array[i]==dcache_addr_reg && rs_ready_to_dispatch[i] && dcache_read) begin
        //    remove_rs_for_dcache = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
        end
        if (addr_array[i]==remove_prefetch_addr && remove_prefetch && prefetch_done) begin
            remove_rs_for_prefetch = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
        end
            // remove_rs_for_dcache = ($clog2(NUM_RS + 1))'(unsigned'(i + 1));

    end
end

always_comb begin
    //remove_rs_for_icache   = '0;
    remove_rs_for_dcache  = '0;
    //remove_rs_for_prefetch = '0;
    // (1) Go through each reservation station
    for (int i=0;i<NUM_RS;i++) begin
        if (addr_array[i]==icache_addr_reg && rs_ready_to_dispatch[i] && icache_read && icache_read_reg) begin
        //    remove_rs_for_icache = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
        end
        else if (addr_array[i]==dcache_addr_reg && rs_ready_to_dispatch[i] && dcache_read) begin
            remove_rs_for_dcache = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
        end
        if (addr_array[i]==remove_prefetch_addr && remove_prefetch && prefetch_done) begin
        //    remove_rs_for_prefetch = ($clog2(NUM_RS + 1))'(unsigned'(i) + 1);
        end
            // remove_rs_for_dcache = ($clog2(NUM_RS + 1))'(unsigned'(i + 1));

    end
end


assign dcache_resp = (wr_done|(remove_rs_for_dcache != '0 ))?'1:'0;
assign icache_resp = ((remove_rs_for_icache != '0 ))?'1:'0;
assign icache_rdata = ( (remove_rs_for_icache != '0 )) ? data[remove_rs_for_icache - 1] : '0;
assign dcache_rdata = ( (remove_rs_for_dcache != '0 )) ? data[remove_rs_for_dcache - 1] : '0;

endmodule : bmem_controller

