`include "hs_macro.sv"
module hs_arbitrate_leaders #(
    parameter integer Leaders        = 2,
    parameter integer LeaderSelWidth = Leaders == 1 ? 1 : $clog2(Leaders)
) (
           hs_io.flw                      flw_hs[Leaders],
           hs_io.ldr                      ldr_hs,
    output logic     [LeaderSelWidth-1:0] addr,
    output logic     [       Leaders-1:0] mask
);
    wire clk = ldr_hs.clk;
    wire clk_en = ldr_hs.clk_en;
    wire sync_rst = ldr_hs.sync_rst;

    `HS_ASSERT_H(flw_hs[0], ldr_hs)

    typedef logic [Leaders-1:0] mask_t;
    typedef logic [flw_hs[0].W-1:0] data_t;

    mask_t reqs;
    mask_t lasts;
    data_t flw_data[Leaders];

    genvar i;
    generate
        for (i = 0; i < Leaders; i = i + 1) begin : g_conn
            assign reqs[i]            = flw_hs[i].ldrv.req;
            assign lasts[i]           = flw_hs[i].ldrv.last;
            assign flw_data[i]        = data_t'(flw_hs[i].data);
            assign flw_hs[i].fdrv.ack = ldr_hs.fdrv.ack && mask[i];
            assign flw_hs[i].fctl     = '0;  // We don't use fctl
        end
        assign ldr_hs.data = type (ldr_hs.data)'(flw_data[addr]);
    endgenerate

    assign ldr_hs.ldrv.req  = |(reqs & mask);
    assign ldr_hs.ldrv.last = |(lasts & mask);
    assign ldr_hs.lctl      = '0;  // We don't use lctl

    wire bus_is_free = ldr_hs.flag.done || !ldr_hs.flag.live || !(|mask);
    _hs_round_robin #(
        .Width(Leaders)
    ) _hs_round_robin (
        .clk      (clk),
        .clk_en   (clk_en),
        .sync_rst (sync_rst),
        .advance_i(bus_is_free),
        .mask_i   (reqs),
        .mask_o   (mask),
        .index_o  (addr)
    );

endmodule
