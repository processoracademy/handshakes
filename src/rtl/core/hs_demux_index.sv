`include "hs_macro.sv"
module hs_demux_index #(
    parameter integer Handshakes       = 2,
    parameter integer _HandshakesWidth = Handshakes == 1 ? 1 : $clog2(Handshakes)
) (
          hs_io.flw                        flw_hs,
          hs_io.ldr                        ldr_hs [Handshakes],
    input logic     [_HandshakesWidth-1:0] index_i
);
    typedef logic [Handshakes-1:0] mask_t;
    mask_t mask;
    assign mask = mask_t'(1) << index_i;

    `HS_ASSERT_H(flw_hs, ldr_hs[0])

    hs_demux_mask #(
        .Handshakes(Handshakes)
    ) hs_demux_mask (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs),
        .mask_i(mask)
    );

endmodule : hs_demux_index
