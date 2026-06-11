`include "hs_macro.sv"
/**
 * Module: hs_broadcast
 * 
 * Ports:
 *  flw_hs - Interface to broadcast
 *  ldr_hs - Broadcast recipients
 * 
 * Parameters:
 *  Handshakes - The number of handshakes in the ldr_hs <hs_io> handshake array
 * 
 * Quinn Unger 02/July/2025
**/
module hs_broadcast #(
    parameter integer Handshakes  = 2,
    parameter logic   UseNewDemux = 1'b0
) (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs[Handshakes]
);
    typedef logic [Handshakes-1:0] mask_t;
    localparam mask_t SetAll = '1;

    `HS_ASSERT_H(flw_hs, ldr_hs[0])

    hs_demux_mask #(
        .Handshakes (Handshakes),
        .UseNewDemux(UseNewDemux)
    ) hs_demux_mask (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs),
        .mask_i(SetAll)
    );

endmodule : hs_broadcast
