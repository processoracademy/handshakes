`include "hs_macro.sv"
/**
 * Module: hs_demux_mask
 * 
 * Use mask_i to connect flw_hs to one or more downstream ldr_hs handshakes.
 * Multiple bits set acts as a broadcast handshake.
 * 
 * mask_i is sampled on flw_hs.flag.init
 * 
 * Ports:
 *  flw_hs - Interface to demux
 *  ldr_hs - array of handshakes, driven by flw_hs if their associated mask_i bit is set
 *  mask_i - configuration mask with each bit corresponding to a ldr_hs handshake at the same index
 * 
 * Parameters:
 *  Bare       - set to 1'b1 to leave all the <hs_io> .data ports disconnected
 *  Handshakes - The number of handshakes in the ldr_hs <hs_io> handshake array
 * 
 * Quinn Unger 02/July/2025
**/
module hs_demux_mask #(
    parameter integer Handshakes  = 2,
    parameter logic   UseNewDemux = 1'b0
) (
          hs_io.flw                  flw_hs,
          hs_io.ldr                  ldr_hs[Handshakes],
    input logic     [Handshakes-1:0] mask_i
);
    generate
        if (UseNewDemux) begin : g_new_demux
            hs_demux_mask_new #(.Handshakes(Handshakes)) hs_demux_mask_new (.*);
        end
        else begin : g_old_demux
            hs_demux_mask_old #(.Handshakes(Handshakes)) hs_demux_mask_old (.*);
        end
    endgenerate

endmodule : hs_demux_mask
