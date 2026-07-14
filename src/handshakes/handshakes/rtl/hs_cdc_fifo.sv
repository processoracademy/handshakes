`include "hs_macro.sv"
module hs_cdc_fifo #(
    parameter integer unsigned AddrW = 3
) (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);

    `HS_ASSERT_H(flw_hs, ldr_hs)

    wire wr_clk = flw_hs.clk;
    wire wr_clk_en = flw_hs.clk_en;
    wire wr_sync_rst = flw_hs.sync_rst;
    wire rd_clk = ldr_hs.clk;
    wire rd_clk_en = ldr_hs.clk_en;
    wire rd_sync_rst = ldr_hs.sync_rst;

    typedef logic [flw_hs.W-1:0] data_t;
    typedef struct packed {
        data_t data;
        logic  close;
    } frame_s;

    hs_io #(
        .T(data_t)
    ) deref_hs (
        .clk     (wr_clk),
        .clk_en  (wr_clk_en),
        .sync_rst(wr_sync_rst)
    );

    hs_replace_data hs_replace_data (
        .flw_hs(flw_hs),
        .ldr_hs(deref_hs),
        .data_i(flw_hs.data)
    );

    hs_io #(
        .T(data_t)
    ) write_hs (
        .clk     (wr_clk),
        .clk_en  (wr_clk_en),
        .sync_rst(wr_sync_rst)
    );

    hs_absorb_aborts hs_absorb_aborts (
        .flw_hs(deref_hs),
        .ldr_hs(write_hs)
    );

    logic      wr_en;
    logic      full;
    wire       gated_full = full || !wr_clk_en;
    frame_s    din;

    hs::fctl_s fctl;
    assign write_hs.fdrv = hs::drive_flw(write_hs.state, fctl);
    assign fctl.ready    = !gated_full;
    assign fctl.pause    = gated_full;
    assign fctl.block    = 1'b0;
    assign wr_en         = write_hs.ldrv.req && !gated_full;
    assign din.data      = write_hs.data;
    assign din.close     = write_hs.flag.exit;

    logic   fifo_rd_en;
    logic   fifo_empty;
    frame_s fifo_dout;

    dual_clock_fifo #(
        .ADDR_WIDTH(AddrW),
        .DATA_WIDTH($bits(frame_s))
    ) dual_clock_fifo (
        .wr_clk_i (wr_clk),
        .wr_rst_i (wr_sync_rst),
        .wr_en_i  (wr_en),
        .wr_data_i(din),
        .full_o   (full),

        .rd_clk_i (rd_clk),
        .rd_rst_i (rd_sync_rst),
        .rd_en_i  (fifo_rd_en),
        .rd_data_o(fifo_dout),
        .empty_o  (fifo_empty)
    );

    frame_s dout;
    logic   rd_en;
    logic   empty;
    wire    gated_fifo_empty = fifo_empty || !rd_clk_en;
    fifo_fwft_adapter #(
        .DATA_WIDTH($bits(frame_s))
    ) fifo_fwft_adapter (
        .clk         (rd_clk),
        .rst         (rd_sync_rst),
        .rd_en_i     (rd_en),
        .fifo_empty_i(gated_fifo_empty),
        .fifo_rd_en_o(fifo_rd_en),
        .fifo_dout_i (fifo_dout),
        .dout_o      (dout),
        .empty_o     (empty)
    );

    hs::lctl_s lctl;
    assign ldr_hs.ldrv = hs::drive_ldr(ldr_hs.state, lctl);
    assign ldr_hs.data = `HS_CAST(ldr_hs, dout.data);
    assign lctl.start  = !empty;
    assign lctl.pause  = empty;
    assign lctl.close  = dout.close;
    assign lctl.abort  = 1'b0;
    assign rd_en       = rd_clk_en && ldr_hs.fdrv.ack && (ldr_hs.state != hs::BLOCK);

    logic prev_reset_0, prev_reset_1;
    always_ff @(posedge rd_clk) begin
        prev_reset_0 <= rd_sync_rst;
        prev_reset_1 <= prev_reset_0;
        if (prev_reset_1 && (!prev_reset_0) && (!rd_sync_rst) && (!fifo_empty)) begin
            $fatal(1, "Reset was not held long enough for dual_clock_fifo to be reset!");
        end
    end
endmodule

