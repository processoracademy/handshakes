`include "hs_macro.sv"
module hs_squish #(
    parameter integer MaxSize = 32,
    parameter integer Frames  = 1
) (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    typedef logic [flw_hs.W-1:0] data_t;

    hs_io #(.T(data_t)) internal_0_hs (.*);

    hs_replace_data hs_replace_data (
        .flw_hs(flw_hs),
        .ldr_hs(internal_0_hs),
        .data_i(data_t'(flw_hs.data))
    );

    hs::fctl_s fctl;
    hs_io #(.T(logic)) allow_0_hs (.*);
    always_comb begin
        fctl.ready = allow_0_hs.state == hs::READY;
        fctl.pause = 1'b0;
        fctl.block = 1'b0;
    end
    hs_io #(.T(data_t)) internal_1_hs (.*);
    hs_override_fctl hs_override_fctl (
        .flw_hs(internal_0_hs),
        .ldr_hs(internal_1_hs),
        .fctl_i(fctl)
    );

    hs_capture_on_rising_edge hs_capture_on_rising_edge (
        .ldr_hs (allow_0_hs),
        .sense_i(internal_1_hs.flag.exit),
        .data_i (1'b0)
    );

    hs_io #(.T(logic)) allow_1_hs (.*);
    hs_fifo #(
        .Depth(Frames)
    ) hs_fifo_tails (
        .flw_hs(allow_0_hs),
        .ldr_hs(allow_1_hs)
    );

    hs_io #(.T(data_t)) internal_2_hs (.*);
    hs_fifo #(
        .Depth       (MaxSize),
        .BufferAborts(1'b0)
    ) hs_fifo_data (
        .flw_hs(internal_1_hs),
        .ldr_hs(internal_2_hs)
    );

    hs_sync #(
        .Handshakes(2),
        .SyncPolicy(hs::FrameSync)
    ) hs_sync (
        .fprobes_i({internal_2_hs.fprobe, allow_1_hs.fprobe}),
        .fdrvs_o  ({internal_2_hs.fdrv, allow_1_hs.fdrv}),
        .lprobe_i (ldr_hs.lprobe),
        .ldrv_o   (ldr_hs.ldrv)
    );
    assign ldr_hs.data = `HS_CAST(ldr_hs, internal_2_hs.data);

endmodule : hs_squish
