`include "hs_macro.sv"

module hs_buffer (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    // functionally equivalent
    `HS_ASSERT_H(flw_hs, ldr_hs)
    hs_absorb_aborts hs_absorb_aborts (.*);
endmodule : hs_buffer
