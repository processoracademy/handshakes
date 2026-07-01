module hs_absorb_aborts (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    initial $warning("hs_absorb_aborts is a deprecated!");
    // hs_filter internally handles aborts correctly.
    hs_filter hs_filter (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs),
        .pass_i(1'b1)
    );

endmodule : hs_absorb_aborts
