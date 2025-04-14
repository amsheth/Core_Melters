// This is a generic transparent regfile with a parameters for the number
// of read and write ports. 

// This allows for multiple writes. In case of colliding
// writes, behavior at worst is UNDEFINED. Further investigation is needed, however
// in best case, writes with colliding selects will result in the highest indexed port's value
// being written. Similar behavior is applied when determining transparency.

// Address 0 is reserved for the value 0

module transparent_regfile #(
    parameter   SELECT_WIDTH    = 6,
    parameter   DATA_WIDTH      = 32,
    parameter   NUM_WRITE_PORT  = 1,
    parameter   NUM_READ_PORT   = 6,
    parameter   COUNT           = 48 
)
(
    input   logic                           clk,
    // input   logic                           rst,

    input   logic                           w_enb   [NUM_WRITE_PORT],
    input   logic   [SELECT_WIDTH - 1:0]    w_sel   [NUM_WRITE_PORT],
    input   logic   [DATA_WIDTH - 1:0]      w_val   [NUM_WRITE_PORT], 

    input   logic   [SELECT_WIDTH - 1:0]    r_sel   [NUM_READ_PORT], 
    output  logic   [DATA_WIDTH - 1:0]      r_val   [NUM_READ_PORT] 
);
    // localparam COUNT = 1 << SELECT_WIDTH;

    logic   [DATA_WIDTH - 1:0]  data [COUNT];

    always_ff @(posedge clk) begin
        // if (rst) begin
        //     for (int i = 0; i < COUNT; i++) begin
        //         data[i] <= '0;
        //     end
        // end else begin
            data[0] <= '0;
            for(int i = 0; i < NUM_WRITE_PORT; i++) begin
                if ((w_enb[i]) & (w_sel[i] != '0))
                    data[w_sel[i]] <= w_val[i];
            end
        // end
    end

    // TODO: Check transparency in TB
    always_comb begin
        for(int read_index = 0; read_index < NUM_READ_PORT; read_index++) begin
            r_val[read_index] = {DATA_WIDTH{~(r_sel[read_index] == '0)}} & data[r_sel[read_index]];

        end
    end
endmodule : transparent_regfile;
