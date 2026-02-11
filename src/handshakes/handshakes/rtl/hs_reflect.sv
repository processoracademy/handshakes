`include "hs_macro.sv"
module hs_reflect (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    `HS_ASSERT_H(flw_hs, ldr_hs)
    hs_replace_data hs_replace_data (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs),
        .data_i(flw_hs.data)
    );
endmodule
