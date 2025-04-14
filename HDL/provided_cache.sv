module provided_cache (
    input   logic               clk,
    input   logic               rst,

    input   logic   [31:0]      ufp_addr,
    input   logic   [3:0]       ufp_rmask,
    input   logic   [3:0]       ufp_wmask,
    output  logic   [31:0]      ufp_rdata,
    input   logic   [31:0]      ufp_wdata,
    output  logic               ufp_resp,

    output  logic   [31:0]      dfp_addr,
    output  logic               dfp_read,
    output  logic               dfp_write,
    input   logic   [255:0]     dfp_rdata,
    output  logic   [255:0]     dfp_wdata,
    input   logic               dfp_resp
);

    enum logic [1:0] {
        IDLE, CHECK, LD
    } state, state_next;

            logic   [255:0] data_q;
            logic   [255:0] data_d;
            logic           data_we;

            logic   [26:0]  tag_q;
            logic   [26:0]  tag_d;
            logic           tag_we;

            logic           valid_q;
            logic           valid_d;
            logic           valid_we;

            logic           hit;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_q <= 'x;
            tag_q <= 'x;
            valid_q <= 1'b0;
            state <= IDLE;
        end else begin
            if (data_we) begin
                data_q <= data_d;
            end
            if (tag_we) begin
                tag_q <= tag_d;
            end
            if (valid_we) begin
                valid_q <= valid_d;
            end
            state <= state_next;
        end
    end

    always_comb begin
        hit = valid_q && tag_q == ufp_addr[31:5];
        state_next = state;
        ufp_rdata = 'x;
        ufp_resp = 1'b0;
        dfp_addr = 'x;
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_wdata = 'x;
        data_d = 'x;
        data_we = 1'b0;
        tag_d = 'x;
        tag_we = 1'b0;
        valid_d =  'x;
        valid_we = 1'b0;
        unique case (state)
        IDLE: begin
            if (|ufp_rmask || |ufp_wmask) begin
                state_next = CHECK;
            end
        end
        CHECK: begin
            if (hit) begin
                if (|ufp_rmask) begin
                    ufp_rdata = data_q[ufp_addr[4:2]*32+:32];
                    state_next = IDLE;
                    ufp_resp = 1'b1;
                end
                if (|ufp_wmask) begin
                    automatic logic [31:0] data_mask = {28'd0, ufp_wmask} << {ufp_addr[4:2], 2'd0};
                    automatic logic [255:0] data_ufp = {8{ufp_wdata}};
                    dfp_addr = {tag_q, 5'd0};
                    dfp_write = 1'b1;
                    for (int i = 0; i < 32; i++) begin
                        if (data_mask[i]) begin
                            dfp_wdata[i*8+:8] = data_ufp[i*8+:8];
                        end else begin
                            dfp_wdata[i*8+:8] = data_q[i*8+:8];
                        end
                    end
                    if (dfp_resp) begin
                        state_next = IDLE;
                        valid_d = 1'b0;
                        valid_we = 1'b1;
                        ufp_resp = 1'b1;
                    end
                end
            end else begin
                state_next = LD;
            end
        end
        LD: begin
            dfp_addr = {ufp_addr[31:5], 5'd0};
            dfp_read = 1'b1;
            if (dfp_resp) begin
                state_next = IDLE;
                data_d = dfp_rdata;
                data_we = 1'b1;
                tag_d = ufp_addr[31:5];
                tag_we = 1'b1;
                valid_d = 1'b1;
                valid_we = 1'b1;
            end
        end
        default: begin
            state_next = IDLE;
        end
        endcase
    end

endmodule
