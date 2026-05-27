module sram_arbiter (
    input  logic        clk,
    input  logic        reset,

    input  logic        wr_valid,
    output logic        wr_ready,
    input  logic [19:0] wr_addr,
    input  logic [15:0] wr_data,

    input  logic        rd_req,
    output logic        rd_ready,
    input  logic [19:0] rd_addr,
    output logic        rd_valid,
    output logic [15:0] rd_data,

    output logic [31:0] wr_accept_count,
    output logic [31:0] rd_accept_count,

    output logic [19:0] SRAM_ADDR,
    inout  wire  [15:0] SRAM_DQ,
    output logic        SRAM_CE_N,
    output logic        SRAM_OE_N,
    output logic        SRAM_WE_N,
    output logic        SRAM_UB_N,
    output logic        SRAM_LB_N
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_READ,
        ST_WRITE
    } state_t;

    state_t      state;
    logic [15:0] dq_out;
    logic        dq_oe;

    assign SRAM_DQ = dq_oe ? dq_out : 16'hzzzz;
    assign SRAM_UB_N = 1'b0;
    assign SRAM_LB_N = 1'b0;

    assign rd_ready = (state == ST_IDLE);
    assign wr_ready = (state == ST_IDLE) && !rd_req;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_IDLE;
            SRAM_ADDR <= 20'h0;
            SRAM_CE_N <= 1'b0;
            SRAM_OE_N <= 1'b1;
            SRAM_WE_N <= 1'b1;
            dq_out <= 16'h0000;
            dq_oe <= 1'b0;
            rd_valid <= 1'b0;
            rd_data <= 16'h0000;
            wr_accept_count <= 32'd0;
            rd_accept_count <= 32'd0;
        end else begin
            rd_valid <= 1'b0;
            SRAM_CE_N <= 1'b0;

            case (state)
                ST_IDLE: begin
                    SRAM_OE_N <= 1'b1;
                    SRAM_WE_N <= 1'b1;
                    dq_oe <= 1'b0;

                    if (rd_req) begin
                        SRAM_ADDR <= rd_addr;
                        SRAM_OE_N <= 1'b0;
                        state <= ST_READ;
                        rd_accept_count <= rd_accept_count + 1'b1;
                    end else if (wr_valid) begin
                        SRAM_ADDR <= wr_addr;
                        dq_out <= wr_data;
                        dq_oe <= 1'b1;
                        SRAM_WE_N <= 1'b0;
                        state <= ST_WRITE;
                        wr_accept_count <= wr_accept_count + 1'b1;
                    end
                end

                ST_READ: begin
                    rd_data <= SRAM_DQ;
                    rd_valid <= 1'b1;
                    SRAM_OE_N <= 1'b1;
                    state <= ST_IDLE;
                end

                ST_WRITE: begin
                    SRAM_WE_N <= 1'b1;
                    dq_oe <= 1'b0;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
