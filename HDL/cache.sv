module cache 
import mem_types::*;#(
    parameter NUM_WAYS = 2
    // parameter NUM_SETS = 32
)(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing portcache_t
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

    localparam SET_SIZE = ($clog2(NUM_SETS)+5);

    logic [(31-(SET_SIZE-1)):00] tag_in;
    logic [(31-(SET_SIZE-1)):00] comp[NUM_WAYS] ;
    logic [($clog2(NUM_SETS)-1):00] set_addr;
    logic [04:00] offset;
    logic [255:0] dout [NUM_WAYS];
    logic valid[NUM_WAYS];
    logic web[NUM_WAYS];
    logic [$clog2(NUM_WAYS)-1:0] x,i;
    logic resp,halt;
    logic [31:0] rdata;
    logic [31:0] addr;
    logic [255:0]din;
    logic [255:0]dfp_data;
    logic [31:0] wmask;
    logic vvv,vwb,lru_update;
    bit miss,commit;
    logic [NUM_WAYS-1:0] lru_way,lru_din;
    // assign miss=valid[3] & (comp[3][22:0]==ball2.tag);
    // logic
    // assign ihalt=halt|rst;

    enum int unsigned {
        s_hit,
        s_ready,
        s_clean_miss,
        s_dirty,
        s_wb,
        s_write
    } state, state_next;

    cache_t ball1,ball2;
    assign commit=(ufp_rmask!='0)||(ufp_wmask!='0);
    // assign commit=((ufp_rmask!=='0)&&(ufp_rmask!=='x))||((ufp_wmask!=='0)&&(ufp_wmask!=='x));

    assign ball1.tag=ufp_addr[31:(($clog2(NUM_SETS))+5)];
    assign ball1.set_addr=ufp_addr[(SET_SIZE-1):5];
    assign ball1.offset=ufp_addr[4:0];
    assign ball1.ufp_addr=ufp_addr;
    assign ball1.ufp_rmask=ufp_rmask;
    assign ball1.ufp_wmask=ufp_wmask;
    assign ball1.ufp_wdata=ufp_wdata;

    // assign set_addr=ufp_addr[8:5];


    // always_comb begin
        
    // end


    always_ff @( posedge clk ) begin
    // always_comb begin
        // if (rst) begin
        //     ball1.rst<='1;
        //     ball2.rst<='1;
        // end
        // else 
        // miss<=commit;
        if ((state==s_write)&&commit)//&&commit)
            ball2<=ball1;
        else if (!halt&&commit)
            ball2<=ball1;       
    end
    

    generate for (genvar y = 0; y < NUM_WAYS; y++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       ('0),
            .web0       (web[y]),
            .wmask0     (wmask),
            .addr0      (set_addr),
            .din0       (din),
            .dout0      (dout[y])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       ('0),
            .web0       ((web[y])),
            .addr0      (set_addr),
            .din0       (tag_in),
            .dout0      (comp[y])
        );
        valid_array #(.S_INDEX(($clog2(NUM_SETS)))) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       ('0),
            .web0       ((web[y])),
            .addr0      (set_addr),
            .din0       (vvv),
            .dout0      (valid[y])
        );
    end endgenerate

    lru_array #(.WIDTH(NUM_WAYS), .S_INDEX(($clog2(NUM_SETS)))) lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       ('0),
        .web0       (lru_update),
        .addr0      (ball2.set_addr),
        .din0       (lru_din),
        .dout0      (),
        .csb1       ('0),
        .web1       ('1),
        .addr1      (ball2.set_addr),
        .din1       ('0),
        .dout1      (lru_way)
    );

    ////borrowed from  https://github.com/brandonhamilton/GPGPU/tree/master //////////
    always_comb begin
        // if (lru_way[0])
        //     x=1'b1;
        // else
        //     x=1'b0;
        x='0;
        for (int k=0;k<NUM_WAYS;k++) begin
            if (lru_way[k]) begin
                x=($clog2(NUM_WAYS))'(unsigned'(k));//k[$clog2(NUM_WAYS)-1:0];
                break;
            end
        end

    end

    always_comb begin
        lru_din='0;
        lru_din[i+1]=1'b1;
        
        // unique case (i)
        //     2'b00: begin
        //         // lru_din[1]='1;
        //         // lru_din[2]='1;
        //         lru_din[0]=~lru_way[0];
        //     end
        //     2'b01:begin
        //         // lru_din[1]='1;
        //         // lru_din[2]='0;
        //         lru_din[0]=~lru_way[0];
        //     end
        // endcase

    end


    // always_comb begin
    //     ufp_rdata='0;
    //     if (!halt)
    //         ufp_rdata=rdata;
    // end
    // assign halt='0;

    always_ff @ (posedge clk) begin
        if (rst)
            state <= s_ready;
        else 
            state <= state_next;
    end
    always_ff @ (posedge clk) begin
        if (dfp_resp)
            dfp_data<=dfp_rdata;
    end

    // always_comb begin

    //     if (offset)

    // end
    logic wset,no_val;
    assign  ufp_rdata=rdata;
    assign set_addr=(halt||wset)?ball2.set_addr:ball1.set_addr;
    // assign miss = (valid[0] && (comp[0][22:0]==ball2.tag)) && (ball2.ufp_rmask!='0);
    // assign miss = (valid[0] && (comp[0][22:0]==ball2.tag)) && (ball2.ufp_rmask!='0);

    always_ff @( posedge clk ) begin
        miss<=(ufp_rmask!='0)||(ufp_wmask!='0);
    end
always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: commit

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: state_next

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
                state_next=state;
        unique case (state)
            s_ready: begin

                state_next=s_ready;
                if (commit) begin
                    state_next=s_hit;
                end
            end
            s_hit : begin
                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
                state_next=s_ready;
                if (miss||commit) begin
                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: dfp_addr

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: tag_in

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: wmask

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: din

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: vvv

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: web

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: dfp_wdata

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: dfp_write

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: wset

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: lru_update

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: halt

always_comb begin
                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: ufp_resp

always_comb begin
//                halt='0;
//                no_val='0;
                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: rdata

always_comb begin
//                halt='0;
//                no_val='0;
//                ufp_resp='0;
//                i='0;
                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
//                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
//                            no_val='1;
                            break;
                        end
//                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end


///////////////////////////////////////////////
///////////////////////////////////////////////
// VAR: no_val

always_comb begin
//                halt='0;
                no_val='0;
//                ufp_resp='0;
//                i='0;
//                rdata='x;
//                halt='0;
//                wmask='0;
//                dfp_addr='0;
//                din='0;
                for (int k=0; k<NUM_WAYS;k++) begin
//                    web[k]='1;
                end
//                dfp_read='0;
//                vvv='0;
//                dfp_wdata='0;
//                dfp_write='0;
//                tag_in='0;
//                wset='0;
//                lru_update='1;
//                state_next=state;
        unique case (state)
            s_ready: begin

//                state_next=s_ready;
                if (commit) begin
//                    state_next=s_hit;
                end
            end
            s_hit : begin
//                state_next=s_hit;
//                halt='1;
                if (ball2.ufp_rmask!='0)   begin
                    for (int k=0; k<NUM_WAYS;k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag)) begin
//                            rdata=dout[k][(ball2.offset*8)+:32];
//                            ufp_resp='1;
//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(unsigned'(k));
//                            halt='0;
//                            state_next=s_ready;
                            no_val='1;
                            if (commit) begin
//                                state_next=s_hit;
                            end
                            break;
                        end
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                            dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end
                end

                else begin
//                    wset='1;
                    for (int unsigned k=0; k<NUM_WAYS; k++) begin
                        if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag))begin
//                            tag_in={1'b1,ball2.tag[(31-(SET_SIZE)):0]};
//                            din=dout[k];
                            for (int unsigned j=0;j<4;j++) begin
                                if (ball2.ufp_wmask[j]) begin
//                                    din[((ball2.offset*8)+j*8)+:8]=ball2.ufp_wdata[j*8+:8];
                                end
                            end

//                            lru_update='0;
//                            i=($clog2(NUM_WAYS))'(k);
//                            web[k]='0;
//                            wmask='1;
//                            vvv='1;
//                            ufp_resp='1;
//                            halt='0;
//                            state_next=s_write; 
                            no_val='1;
                            break;
                        end
                        no_val='0;
                    end
                    if (!valid[x] && !no_val) begin
//                        state_next=s_clean_miss;
//                        halt='1;
//                        dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                    end
                    else if (!no_val) begin
                        if (comp[x][(31-(SET_SIZE-1))]=='0)begin
//                            state_next=s_clean_miss;
//                            halt='1;
//                            dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                        dfp_read='1;
                        end
                        else begin
//                            halt='1;
//                            dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                            dfp_write='1;
//                            state_next=s_dirty;
//                            dfp_wdata=dout[x];
                        end
                    end

                end
            end
            s_clean_miss: begin
//                state_next=s_clean_miss;
//                halt='1;
//                dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                dfp_read='1;
                    
                if (dfp_resp) begin
//                    dfp_addr={ball2.tag,ball2.set_addr,5'b00000};
//                    tag_in={1'b0,ball2.tag[(31-(SET_SIZE)):0]};

//                    din=dfp_rdata;
//                    web[x]='0;
//                    wmask='1;
//                    state_next=s_wb;
//                    vvv='1;
                end


            end
            s_dirty: begin
                
//                halt='1;
//                dfp_addr={comp[x][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                dfp_write='1;
//                state_next=s_dirty;
//                dfp_wdata=dout[x];
                for (int k=0; k<NUM_WAYS; k++) begin
                    if (valid[k] && (comp[k][(31-(SET_SIZE)):0]==ball2.tag) && (comp[k][(31-(SET_SIZE-1))]!='0))begin
//                        halt='1;
//                        dfp_addr={comp[k][(31-(SET_SIZE)):0],ball2.set_addr,5'b00000};
//                        dfp_write='1;
//                        state_next=s_dirty;
//                        dfp_wdata=dout[k];
                        break;
                    end
                end
                if (dfp_resp) begin
//                    state_next=s_clean_miss;
                end
            end
            s_write: begin
//                halt='1;
//                wset='0;
//                state_next=s_ready;
                if (miss||commit) begin
//                    state_next=s_hit;
                end
            end
            s_wb: begin
//                halt='1;
//                state_next=s_hit;
            end
            default : begin 
            end
        endcase


    end








endmodule
