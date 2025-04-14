
/*
* TODO: 
* 1. Add a queue to hold penrdatag addresses
*/

module burst_controller
// import rv32i_types::*;
(
    input   logic                clk,
    input   logic                rst,

    input   logic                mem_rvalid,///incoming data valid
    output  logic [31:0]         mem_addr,
    output  bit                  mem_read,
    output  logic                mem_write,
    output  logic [63:0]         mem_wdata,
    input   logic                mem_ready,
    input   logic [63:0]         mem_rdata,
    // input  logic [31:0]              mem_raddr,

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

    logic [31:0]        cache_addr;
    logic               cache_read;
    logic               cache_write;
    logic [255:0]       cache_rdata;
    logic [255:0]       cache_wdata;
    logic               cache_resp;
    // logic               prev_used_dcache,prev_used_icache;
    logic               prev_used_dcache, prev_used_dcache_reg, ibusy , dbusy, ibusy_non_reg;

    assign ibusy_non_reg = ((icache_read| ((dcache_read | dcache_write) & icache_read & prev_used_dcache_reg))&& !cache_resp && !dbusy);

    always_ff @( posedge clk ) begin
        if (rst) begin
            ibusy<='0;
            dbusy<='0;
        end
        else begin
            if ((icache_read| ((dcache_read | dcache_write) & icache_read & prev_used_dcache_reg))&& !cache_resp && !dbusy)
                ibusy<='1;
            else if (((dcache_read | dcache_write)| ((dcache_read | dcache_write) & icache_read & !prev_used_dcache_reg))&& !cache_resp && !ibusy)
                dbusy<='1;
            else if (cache_resp) begin
                ibusy<='0;
                dbusy<='0;
            end
        end
    end

    always_ff @( posedge clk ) begin
        if (rst) begin
            prev_used_dcache_reg <= '0;
        end else begin
            prev_used_dcache_reg <= prev_used_dcache;
        end
    end

    always_comb begin
        if (rst) begin
            cache_addr           ='0;
            cache_read           ='0;
            cache_write          ='0;
            dcache_rdata         ='0;
            cache_wdata          ='0;
            icache_rdata         ='0;
            icache_resp          ='0;
            dcache_resp          ='0;
            prev_used_dcache ='0;            
        end else begin
            // Reset the cache response signal every cycle
            cache_addr           ='0;
            cache_read           ='0;
            cache_write          ='0;
            dcache_rdata         ='0;
            cache_wdata          ='0;
            icache_rdata         ='0;
            icache_resp          ='0;
            dcache_resp          ='0;
            prev_used_dcache ='0;
            // If we have a dcache request and icache request the same cycle
            if ((dcache_read | dcache_write) & icache_read) begin
                if ((ibusy && !dbusy) | prev_used_dcache_reg) begin
                    cache_addr  =    icache_addr;
                    cache_read  =    icache_read;
                    cache_write =   icache_write;
                    icache_rdata=   cache_rdata;
                    cache_wdata =   icache_wdata;
                    icache_resp =    cache_resp;
                    if (cache_resp)
                        prev_used_dcache = '0;
                end 
                else if (dbusy && !ibusy && !prev_used_dcache_reg && !ibusy_non_reg) begin
                    cache_addr  =    dcache_addr;
                    cache_read  =    dcache_read;
                    cache_write =   dcache_write;
                    dcache_rdata=   cache_rdata;
                    cache_wdata =   dcache_wdata;
                    dcache_resp =    cache_resp;
                    if (cache_resp)
                        prev_used_dcache = '1;
                end
            end else if ((dcache_read | dcache_write) && !ibusy) begin
                cache_addr  =    dcache_addr;
                cache_read  =    dcache_read;
                cache_write =   dcache_write;
                dcache_rdata=   cache_rdata;
                cache_wdata =   dcache_wdata;
                dcache_resp =    cache_resp;
                if (cache_resp)
                    prev_used_dcache = '1;
            end else if (icache_read && !dbusy) begin
                cache_addr  =    icache_addr;
                cache_read  =    icache_read;
                cache_write =    icache_write;
                icache_rdata=   cache_rdata;
                cache_wdata =    icache_wdata;
                icache_resp =   cache_resp;
                if (cache_resp)
                    prev_used_dcache = '0;
            end else begin  
                cache_addr  = '0;
                cache_read  = '0;
                cache_write = '0;
                dcache_rdata= '0;
                icache_rdata= '0;
                cache_wdata = '0;
                icache_resp ='0;
                dcache_resp ='0;
                // cache_resp  <= '0;
            end
        end
    end


    // always_comb begin
 

    // end

    // always_ff @( posedge clk ) begin 
    //     cache_addr='0;
    //     cache_read='0;
    //     cache_write='0;
    //     cache_rdata='0;
    //     cache_wdata='0;
    //     cache_resp='0;
    //     prev_used_dcache<='0;
    //     prev_used_icache<='0;
    //     if ((dcache_read | dcache_write) && !prev_used_dcache) begin
    //             cache_addr<=    dcache_addr;
    //             cache_read<=    dcache_read;
    //             cache_write<=   dcache_write;
    //             cache_rdata<=   dcache_rdata;
    //             cache_wdata<=   dcache_wdata;
    //             cache_resp<=    dcache_resp;
    //             if (cache_resp)
    //                 prev_used_dcache<='1;
    //     else if ((icache_read | icache_write) && !prev_used_icache) begin
    //             cache_addr<=    icache_addr;
    //             cache_read<=    icache_read;
    //             cache_write<=   icache_write;
    //             cache_rdata<=   icache_rdata;
    //             cache_wdata<=   icache_wdata;
    //             cache_resp<=    icache_resp;
    //             if (cache_resp)
    //                 prev_used_icache<='1; 
    // end

    // logic cache_write_trash; assign cache_write_trash = cache_write;
    // logic [255:0] cache_wdata_trash; assign cache_wdata_trash = cache_wdata; 
    // assign mem_wdata  = '0;
    // assign mem_wdata  = '0;

    // logic [2:0] state;
    logic [255:0] data;
    logic ret,read,wr_done;

    // assign mem_write = 1'b0; // TODO: PLEASE DELETE ME
    // assign mem_write = 1'b0; // TODO: PLEASE DELETE ME
    assign mem_addr=cache_addr;
    // assign mem_read=cache_read;

    enum logic [2:0] { 
        // state_1,
        state_2,
        state_3,
        state_4,
        wstate_2,
        wstate_3,
        wstate_4,
        s_idle
     } state;

    always_ff @( posedge clk ) begin : state_machine
        // mem_read<='0;
        /////reset stage/////
        if (rst) begin
            ret<='0;
            state<=s_idle;
            data<='0;
            wr_done<='0;
            read<='1;
            cache_resp<='0;
            // cache_resp<='0;
            mem_write<='0;
            mem_wdata<='0;
            // cache_resp<='0;
            mem_write<='0;
            mem_wdata<='0;
        end
        // Second data////
        else if (mem_rvalid && (state==state_2)) begin
            state<=state_3;
            data<=data|{128'b0,mem_rdata,64'b0};
            read<='0;
            mem_write<='0;
            cache_resp<='0;
        end

        //// thrid data/////
        else if (mem_rvalid && (state==state_3)) begin
            state<=state_4;
            data<=data|{64'b0,mem_rdata,128'b0};
            read<='0;
            mem_write<='0;
            cache_resp<='0;
        end

        //////final data/////
        else if (mem_rvalid && (state==state_4)) begin
            state<=s_idle;
            data<=data|{mem_rdata,192'b0};
            read<='0;
            cache_resp<='0;
            mem_write<='0;
            ret<='1;
        end

        else if ((state==wstate_2)) begin
            mem_wdata<=cache_wdata[127:64];
            mem_write<='1;
            state<=wstate_3;
            cache_resp<='0;
        end
        else if ((state==wstate_3)) begin
            mem_wdata<=cache_wdata[191:128];
            mem_write<='1;
            state<=wstate_4;
            cache_resp<='0;
        end
        else if ((state==wstate_4)) begin
            mem_wdata<=cache_wdata[255:192];
            mem_write<='1;
            state<=s_idle;
            cache_resp<='1;
            wr_done<='1;
        end
        ////// done and idle state//////
        else if ((state==s_idle)) begin
            state<=s_idle;
            cache_resp<='0;
            mem_write<='0;
            mem_wdata<='0;
            if (cache_read&&read&&!cache_resp&&!(ret|wr_done)&&mem_ready) begin
                read<='0;
                mem_write<='0;
                // mem_read<='1;
            end

            else if (cache_write&& mem_ready&& !(ret|wr_done)) begin
                mem_wdata<=cache_wdata[63:0];
                mem_write<='1;
                state<=wstate_2;
            end

            if (wr_done) begin
                cache_resp<='0;
                state<=s_idle; //// force an extra idle state//////
                wr_done<='0;
                read<='1;
                mem_write<='0;
            end            
            ////// done state ///////
            if (ret) begin
                cache_resp<='1;
                state<=s_idle; //// force an extra idle state//////
                ret<='0;
                read<='1;
                mem_write<='0;
            end
            else begin
                cache_resp<='0;
                // mem_write<='0;
            end
            //////// idle state and not done state///////
            if (mem_rvalid&&!ret) begin
            read<='0;
            state<=state_2;
            data<=256'h0|{192'h0,mem_rdata};
            cache_resp<='0;
            mem_write<='0;
            end
        end
    end

    assign mem_read = (cache_read && read && !(ret|wr_done) && !cache_resp) ? '1 : '0;

    assign cache_rdata= (cache_resp)?data:'x;

    // always_comb begin : state_controllerz
    //     unique case (state)
    //         3'b000:begin
    //             data[63:0]=mem_rdata;
    //             cache_resp='0;
    //             ret='0;
    //         end
    //         3'b001:begin
    //             data[127:64]=mem_rdata;
    //             cache_resp='0;
    //             ret='0;
    //         end
    //         3'b010:begin
    //             data[195:128]=mem_rdata;
    //             cache_resp='0;
    //             ret='0;
    //         end
    //         3'b011:begin
    //             data[255:196]=mem_rdata;
    //             cache_resp='1;
    //             ret='1;
    //         end
    //         // 3'b100:begin

    //         // end
    //         default: begin
    //             ret='1;
    //             cache_resp='0;
    //             data[255:0]='0;
    //         end
    //     endcase 
    // end
















endmodule : burst_controller
