// Add one word of latency in order to absorb aborts.
// This ensures that the hs frame always exits on valid data.
module hs_absorb_aborts (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    hs_register #(.AbsorbAborts(1'b1)) hs_register (.*);
endmodule : hs_absorb_aborts
