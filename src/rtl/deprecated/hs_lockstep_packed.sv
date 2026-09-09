`include "hs_macro.sv"

module hs_lockstep_packed #(
    parameter integer Handshakes = 1
) (
    hs_io.flw flw_hs[Handshakes],
    hs_io.ldr ldr_hs
);
    initial $warning("hs_lockstep_packed is deprecated!");
    wire clk = ldr_hs.clk;
    wire clk_en = ldr_hs.clk_en;
    wire sync_rst = ldr_hs.sync_rst;

    // ldr_hs must be a multiple of flw_hs width * Handshakes
    typedef logic [(ldr_hs.W/Handshakes)-1:0] flw_t;
    typedef logic [Handshakes-1:0][$bits(flw_t)-1:0] ldr_t;
    typedef logic [Handshakes-1:0][$bits(hs::fprobe_s)-1:0] fprobes_t;
    typedef logic [Handshakes-1:0][$bits(hs::fdrv_s)-1:0] fdrvs_t;

    fprobes_t fprobes;
    fdrvs_t   fdrvs;
    ldr_t     data;
    genvar i;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_dereference_handshakes
            assign fprobes[i]     = flw_hs[i].fprobe;
            assign flw_hs[i].fdrv = fdrvs[i];
            assign data[i]        = flw_hs[i].data;
        end
    endgenerate

    hs_sync #(
        .Handshakes(Handshakes),
        .SyncPolicy(hs::Truncate)
    ) hs_sync (
        .fprobes_i(fprobes),
        .fdrvs_o  (fdrvs),
        .lprobe_i (ldr_hs.lprobe),
        .ldrv_o   (ldr_hs.ldrv)
    );
    assign ldr_hs.data = data;

endmodule : hs_lockstep_packed
