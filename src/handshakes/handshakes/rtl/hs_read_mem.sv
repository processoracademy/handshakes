`include "hs_macro.sv"

module hs_read_mem (
    hs_io.flw read_i_hs,
    hs_io.ldr read_o_hs,

    input  type(read_o_hs.data) mem_data_i,
    output type(read_i_hs.data) mem_ptr_o
);
    wire clk = read_i_hs.clk;
    wire clk_en = read_i_hs.clk_en;
    wire sync_rst = read_i_hs.sync_rst;

    hs::lctl_s read_o_lctl;
    `HS_DRIVE_LDR(read_o_hs, read_o_lctl)

    hs::fctl_s read_i_fctl;
    `HS_DRIVE_FLW(read_i_hs, read_i_fctl)

    typedef logic [read_i_hs.W-1:0] ptr_t;
    typedef logic [read_o_hs.W-1:0] data_t;

    typedef struct packed {
        hs::flag_s flag;
        ptr_t      ptr;
    } ptr_frame_s;

    typedef struct packed {
        hs::flag_s flag;
        data_t     data;
    } read_frame_s;

    ptr_frame_s ptr_frame;
    read_frame_s read_frame, buffer_frame, output_frame;
    hs::flag_s data_flag;

    logic      read_enable;
    logic      unblock;

    assign read_enable          = read_o_hs.flag.good || (!output_frame.flag.good);

    assign unblock              = read_o_hs.flag.done || ((!hs::flw_active(read_o_hs.state)) && output_frame.flag.term);

    assign read_i_fctl.ready = read_enable;
    assign read_i_fctl.pause = !read_enable;
    assign read_i_fctl.block = !unblock;

    assign ptr_frame.flag       = read_i_hs.flag;
    assign ptr_frame.ptr        = ptr_t'(read_i_hs.data);

    assign mem_ptr_o            = ptr_frame.ptr;

    always_ff @(posedge clk) begin
        if (sync_rst) begin
            data_flag <= '0;
        end
        else begin
            data_flag <= ptr_frame.flag;
        end
    end

    // inject sticky term flag so it persists while buffer_frame is pending
    logic term_pending;
    wire  term_set = data_flag.term || term_pending;
    wire  term_clr = output_frame.flag.term;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            term_pending <= 1'b0;
        end
        else if (clk_en) begin
            term_pending <= term_set && !term_clr;
        end
    end

    always_comb begin
        read_frame.data = data_t'(mem_data_i);
        read_frame.flag = data_flag;
        if (term_pending) begin
            read_frame.flag.term = 1'b1;
        end
    end

    // only care about buffering good frames, term frames are dealt with via sticky flag on read_frame
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            buffer_frame <= '0;
        end
        else if (clk_en) begin
            unique case ({
                read_frame.flag.good, buffer_frame.flag.good, read_o_hs.flag.good
            })
                3'b000: begin
                end  // do nothing (empty)
                3'b001: begin
                end  // do nothing (this case should never happen!)
                3'b010: begin
                end  // do nothing (buffer_frame pending)
                3'b011: buffer_frame <= '0;  // clear this buffer (buffer_frame sent)
                3'b100: buffer_frame <= read_frame;  // copy read_frame to buffer_frame
                3'b111: buffer_frame <= read_frame;  // copy read_frame to buffer_frame
                3'b101: begin
                end  // do nothing (read_frame is forwarded to output_frame)
                3'b110: begin
                end  // do nothing
            endcase
        end
    end

    assign output_frame   = buffer_frame.flag.good ? buffer_frame : read_frame;

    assign read_o_hs.data = `HS_CAST(read_o_hs, output_frame.data);
    always_comb begin
        if (read_o_hs.state == hs::BLOCK) begin
            read_o_lctl = hs::LctlIdle;
        end
        else begin
            read_o_lctl.start = output_frame.flag.good;
            read_o_lctl.pause = !output_frame.flag.good;
            read_o_lctl.close = output_frame.flag.exit;
            read_o_lctl.abort = output_frame.flag.term;
        end
    end

endmodule : hs_read_mem
