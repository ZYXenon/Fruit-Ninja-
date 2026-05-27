module sram_frame_writer #(
    parameter int FRAME_WORDS = 76800
) (
    input  logic        clk,
    input  logic        reset,

    input  logic        fifo_valid,
    output logic        fifo_ready,
    input  logic [17:0] fifo_data,

    output logic        mem_wr_valid,
    input  logic        mem_wr_ready,
    output logic [19:0] mem_wr_addr,
    output logic [15:0] mem_wr_data,

    input  logic [1:0]  read_frame,
    input  logic        pending_consumed,
    output logic [1:0]  pending_frame,
    output logic        pending_valid,

    output logic [31:0] accepted_pixel_count,
    output logic [31:0] completed_frame_count,
    output logic [31:0] dropped_frame_count,
    output logic [16:0] debug_pixel_count
);

    logic [1:0]  write_frame;
    logic [16:0] pixel_count;
    logic        frame_active;
    logic        sof;
    logic        need_write;
    logic        fifo_accepted;
    logic        wr_accepted;
    logic [16:0] write_offset;
    localparam logic [16:0] FRAME_WORDS_L = FRAME_WORDS;

    function automatic logic [19:0] frame_base(input logic [1:0] frame);
        case (frame)
            2'd0: frame_base = 20'd0;
            2'd1: frame_base = 20'd76800;
            default: frame_base = 20'd153600;
        endcase
    endfunction

    function automatic logic [1:0] pick_next_frame(input logic [1:0] current_read, input logic [1:0] hold_frame);
        if ((2'd0 != current_read) && (2'd0 != hold_frame)) begin
            pick_next_frame = 2'd0;
        end else if ((2'd1 != current_read) && (2'd1 != hold_frame)) begin
            pick_next_frame = 2'd1;
        end else begin
            pick_next_frame = 2'd2;
        end
    endfunction

    assign sof = fifo_data[17];
    assign write_offset = sof ? 17'd0 : pixel_count;
    assign need_write = (sof || frame_active) && (write_offset < FRAME_WORDS_L);
    assign fifo_ready = !need_write || mem_wr_ready;
    assign fifo_accepted = fifo_valid && fifo_ready;
    assign wr_accepted = mem_wr_valid && mem_wr_ready;
    assign mem_wr_valid = fifo_valid && need_write;
    assign mem_wr_addr = frame_base(write_frame) + {{3{1'b0}}, write_offset};
    assign mem_wr_data = fifo_data[15:0];
    assign debug_pixel_count = pixel_count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            write_frame <= 2'd0;
            pixel_count <= 17'd0;
            frame_active <= 1'b0;
            pending_frame <= 2'd0;
            pending_valid <= 1'b0;
            accepted_pixel_count <= 32'd0;
            completed_frame_count <= 32'd0;
            dropped_frame_count <= 32'd0;
        end else begin
            if (pending_consumed) begin
                pending_valid <= 1'b0;
            end

            if (fifo_accepted) begin
                accepted_pixel_count <= accepted_pixel_count + 1'b1;

                if (sof) begin
                    if (frame_active && (pixel_count != 17'd0)) begin
                        dropped_frame_count <= dropped_frame_count + 1'b1;
                    end
                    pixel_count <= 17'd1;
                    frame_active <= 1'b1;
                end else if (frame_active && (pixel_count < FRAME_WORDS_L)) begin
                    pixel_count <= pixel_count + 1'b1;
                end

                if (wr_accepted && (write_offset == (FRAME_WORDS_L - 1'b1))) begin
                    pending_frame <= write_frame;
                    pending_valid <= 1'b1;
                    completed_frame_count <= completed_frame_count + 1'b1;
                    write_frame <= pick_next_frame(read_frame, write_frame);
                    pixel_count <= 17'd0;
                    frame_active <= 1'b0;
                end
            end
        end
    end
endmodule
