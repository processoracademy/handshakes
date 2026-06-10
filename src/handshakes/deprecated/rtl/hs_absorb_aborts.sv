// Add one word of latency in order to absorb aborts.
// This ensures that the hs frame always exits on valid data.
module hs_absorb_aborts (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    initial $warning("hs_absorb_aborts is a deprecated alias for hs_register (aborts are also deprecated!)");
    hs_register hs_register (.*);
endmodule : hs_absorb_aborts
