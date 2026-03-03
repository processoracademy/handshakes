`include "hs_macro.sv"
// Take in contextless flw_hs data and apply our own frame structure.
module hs_reframe (
    hs_io.flw flw_hs,
    hs_io.flw request_hs,
    hs_io.ldr ldr_hs
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs)

    typedef logic [flw_hs.W-1:0] data_t;

    hs_io #(.T(data_t)) internal_hs (.*);
    hs_replace_data hs_replace_data (
        .flw_hs(request_hs),
        .ldr_hs(internal_hs),
        .data_i(data_t'(flw_hs.data))
    );
    hs::fctl_s fctl;
    assign fctl.ready = flw_hs.ldrv.req;
    assign fctl.pause = !flw_hs.ldrv.req;
    assign fctl.block = 1'b0;
    hs_override_fctl hs_override_fctl (
        .flw_hs(internal_hs),
        .ldr_hs(ldr_hs),
        .fctl_i(fctl)
    );

    assign flw_hs.fdrv.ack = internal_hs.ldrv.req && ldr_hs.fdrv.ack && (ldr_hs.state != hs::BLOCK) && (flw_hs.state != hs::BLOCK);

endmodule : hs_reframe
