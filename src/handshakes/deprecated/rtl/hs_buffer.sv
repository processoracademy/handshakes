module hs_buffer (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    initial $warning("hs_buffer is a deprecated alias for hs_register");
    hs_register hs_register (.*);
endmodule : hs_buffer
