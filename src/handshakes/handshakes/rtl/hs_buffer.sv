module hs_buffer (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    hs_register #(.AbsorbAborts(1'b0)) hs_register (.*);
endmodule : hs_buffer
