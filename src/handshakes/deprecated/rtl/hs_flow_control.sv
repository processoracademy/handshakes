`include "hs_macro.sv"
module hs_flow_control (
          hs_io.flw flw_hs,
          hs_io.ldr ldr_hs,
    input logic     ready_i,
    input logic     pause_i,
    input logic     block_i
);
    initial $warning("hs_flow_control is deprecated!");

    hs::fctl_s fctl;
    assign fctl.ready = ready_i;
    assign fctl.pause = pause_i;
    assign fctl.block = block_i;
    hs_override_fctl hs_override_fctl (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs),
        .fctl_i(fctl)
    );

endmodule : hs_flow_control
