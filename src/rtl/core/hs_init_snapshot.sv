`include "hs_macro.sv"
module hs_init_snapshot (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs,
    hs_io.ldr snapshot_hs,

    input type(snapshot_hs.data) data_i
);
    `HS_ASSERT_H(flw_hs, ldr_hs)
    // Ensure snapshot has been consumed before progressing to the next frame
    hs::fctl_s fctl;
    assign fctl.ready = 1'b1;
    assign fctl.pause = 1'b0;
    assign fctl.block = flw_hs.prev_flag.init || (snapshot_hs.state != hs::READY);
    hs_override_fctl hs_override_fctl (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs),
        .fctl_i(fctl)
    );

    hs_capture_on_rising_edge hs_capture_on_rising_edge (
        .ldr_hs (snapshot_hs),
        .sense_i(flw_hs.flag.init),
        .data_i (data_i)
    );

endmodule : hs_init_snapshot
