`include "hs_macro.sv"
module hs_arbitrate_followers #(
    parameter logic   Frameless      = 1'b0,
    parameter integer Followers      = 2,
    parameter integer FollowSelWidth = Followers == 1 ? 1 : $clog2(Followers)
) (
           hs_io.flw                      flw_hs,
           hs_io.ldr                      ldr_hs[Followers],
    output logic     [FollowSelWidth-1:0] addr,
    output logic     [     Followers-1:0] mask
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs[0])

    typedef type (mask) mask_t;
    mask_t acks;
    genvar i;
    generate
        for (i = 0; i < Followers; i = i + 1) begin : g_per_handshake
            // If Frameless, we don't let ldr frames end so we don't have to check for blocking.
            assign acks[i]             = ldr_hs[i].fdrv.ack;
            assign ldr_hs[i].ldrv.req  = flw_hs.ldrv.req && mask[i];
            assign ldr_hs[i].ldrv.last = Frameless ? 1'b0 : (flw_hs.ldrv.last && mask[i]);
            assign ldr_hs[i].data      = flw_hs.data;
        end
    endgenerate

    logic advance;
    always_comb begin
        if (Frameless) begin
            flw_hs.fdrv.ack = (flw_hs.state != hs::BLOCK) && |(acks & mask);
            advance         = flw_hs.ldrv.req || !(|mask);
        end
        else begin
            flw_hs.fdrv.ack = |(acks & mask);
            // We expect the bus to be ack'd immediately. Move on otherwise.
            advance         = !hs::flw_active(flw_hs.next_state) || !(|mask);
        end
    end

    _hs_round_robin #(
        .Width(Followers)
    ) _hs_round_robin (
        .clk      (clk),
        .clk_en   (clk_en),
        .sync_rst (sync_rst),
        .advance_i(advance),
        .mask_i   (acks),
        .mask_o   (mask),
        .index_o  (addr)
    );

endmodule : hs_arbitrate_followers
