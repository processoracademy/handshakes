`include "hs_macro.sv"
module hs_frame_switch #(
    parameter integer Handshakes = 2
) (
    hs_io.flw flw_hs,
    hs_io.flw index_hs,
    hs_io.ldr ldr_hs  [Handshakes]
);
    localparam integer IndexW = Handshakes == 1 ? 1 : $clog2(Handshakes);
    typedef logic [flw_hs.W-1:0] data_t;
    typedef logic [IndexW-1:0] index_t;

    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_EXPECT_ONESHOT(index_hs)
    `HS_ASSERT_W(index_hs, IndexW)
    `HS_ASSERT_H(flw_hs, ldr_hs[0])

    typedef struct packed {
        index_t index;
        data_t  data;
    } frame_s;

    hs_io #(.T(frame_s)) source_hs (.*);
    hs_sync #(
        .Handshakes(2),
        .SyncPolicy(hs::FrameSync)
    ) hs_sync (
        .fprobes_i({flw_hs.fprobe, index_hs.fprobe}),
        .fdrvs_o  ({flw_hs.fdrv, index_hs.fdrv}),
        .lprobe_i (source_hs.lprobe),
        .ldrv_o   (source_hs.ldrv)
    );
    assign source_hs.data.index = index_hs.data_stable;
    assign source_hs.data.data  = data_t'(flw_hs.data);

    hs_io #(.T(frame_s)) destination_hs[Handshakes] (.*);
    hs_demux_index #(
        .Handshakes(Handshakes)
    ) hs_demux_index (
        .flw_hs (source_hs),
        .ldr_hs (destination_hs),
        .index_i(source_hs.data.index)
    );

    genvar i;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_output
            hs_replace_data hs_replace_data (
                .flw_hs(destination_hs[i]),
                .ldr_hs(ldr_hs[i]),
                .data_i(type(ldr_hs[i].data)'(destination_hs[i].data.data))
            );
        end
    endgenerate

endmodule : hs_frame_switch
