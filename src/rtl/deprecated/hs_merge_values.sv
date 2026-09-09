`include "hs_macro.sv"
module hs_merge_values (
    hs_io.flw flw_a_hs,
    hs_io.flw flw_b_hs,
    hs_io.ldr ldr_hs,
    input type(ldr_hs.data) data_i
);
    initial $warning("hs_merge_values is deprecated!");

    logic [1:0][$bits(hs::fprobe_s)-1:0] fprobes;
    logic [1:0][  $bits(hs::fdrv_s)-1:0] fdrvs;
    assign fprobes[0]    = flw_a_hs.fprobe;
    assign fprobes[1]    = flw_b_hs.fprobe;
    assign flw_a_hs.fdrv = fdrvs[0];
    assign flw_b_hs.fdrv = fdrvs[1];

    hs_sync #(
        .Handshakes(2),
        .SyncPolicy(hs::FrameSync)
    ) hs_sync (
        .fprobes_i(fprobes),
        .fdrvs_o  (fdrvs),
        .lprobe_i (ldr_hs.lprobe),
        .ldrv_o   (ldr_hs.ldrv)
    );
    assign ldr_hs.data = data_i;

endmodule : hs_merge_values
