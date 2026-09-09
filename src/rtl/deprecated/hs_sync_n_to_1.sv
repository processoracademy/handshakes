`include "hs_macro.sv"
module hs_sync_n_to_1 #(
    parameter integer           Handshakes = 2,
    parameter hs::sync_policy_e SyncPolicy = hs::UndefinedSync
) (
    input  [Handshakes-1:0][$bits(hs::fprobe_s)-1:0] fprobes_i,
    output [Handshakes-1:0][  $bits(hs::fdrv_s)-1:0] fdrvs_o,

    input  hs::lprobe_s lprobe_i,
    output hs::ldrv_s   ldrv_o
);
    initial $warning("hs_sync_n_to_1 has been renamed to hs_sync");
    hs_sync #(.Handshakes(Handshakes),.SyncPolicy(SyncPolicy)) hs_sync (.*);

endmodule : hs_sync_n_to_1
