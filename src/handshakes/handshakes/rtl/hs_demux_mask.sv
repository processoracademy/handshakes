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
    parameter integer Handshakes = 2
) (
          hs_io.flw                  flw_hs,
          hs_io.ldr                  ldr_hs[Handshakes],
    input logic     [Handshakes-1:0] mask_i
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs[0])

    typedef logic [Handshakes-1:0] mask_t;
    mask_t set_mask;
    mask_t set_mask_reg;
    always_ff @(posedge clk) begin
        if (clk_en && flw_hs.flag.init) begin
            set_mask_reg <= mask_i;
        end
    end
    assign set_mask = flw_hs.flag.init ? mask_i : set_mask_reg;

    mask_t pending_reg;
    mask_t pending_clr;
    _hs_sr_vector #(
        .Width          (Handshakes),
        .PrioritizeClear(1'b1)
    ) _hs_sr_vector (
        .clk       (clk),
        .clk_en    (clk_en),
        .sync_rst  (sync_rst),
        .set_i     (set_mask),
        .set_en_i  (flw_hs.flag.good),
        .clear_i   (pending_clr),
        .clear_en_i(1'b1),
        .vector_o  (pending_reg)
    );

    mask_t     ldr_not_ready;
    hs::fctl_s flw_fctl;
    `HS_DRIVE_FLW(flw_hs, flw_fctl)
    assign flw_fctl.ready = 1'b1;
    assign flw_fctl.pause = |pending_reg;  // only high if we didn't get everything last cycle.
    assign flw_fctl.block = |ldr_not_ready;

    genvar i;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_connect_leaders
            logic      pending;
            hs::lctl_s ldr_lctl;
            `HS_DRIVE_LDR(ldr_hs[i], ldr_lctl)

            assign pending = pending_reg[i] || flw_hs.flag.good;  // forward flag.good to avoid handshake bubbles.
            assign ldr_hs[i].data = flw_hs.data_stable;
            assign ldr_lctl.start = flw_hs.flag.init && mask_i[i];
            assign ldr_lctl.pause = !pending;
            assign ldr_lctl.close = (flw_hs.flag.exit || (flw_hs.state == hs::BLOCK)) && pending;
            assign ldr_lctl.abort = (flw_hs.state == hs::BLOCK) && !pending;
            assign pending_clr[i] = ldr_hs[i].flag.good;
            assign ldr_not_ready[i] = pending_reg[i] || (ldr_hs[i].state != hs::READY);
        end
    endgenerate

endmodule : hs_demux_mask
