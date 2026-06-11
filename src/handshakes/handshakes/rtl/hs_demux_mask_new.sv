`include "hs_macro.sv"
/**
 * Module: hs_demux_mask_new
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
 *  Handshakes - The number of handshakes in the ldr_hs <hs_io> handshake array
 * 
 * Quinn Unger 02/July/2025
**/
module hs_demux_mask_new #(
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
    typedef logic [flw_hs.W-1:0] data_t;

    typedef struct packed {
        data_t data;
        mask_t mask;
    } register_s;

    mask_t mask_reg;
    always_ff @(posedge clk) begin
        if (clk_en && flw_hs.flag.init) begin
            mask_reg <= mask_i;
        end
    end

    register_s unregistered;
    assign unregistered.data = flw_hs.data;
    assign unregistered.mask = (flw_hs.state == hs::MULTI) ? mask_reg : mask_i;
    hs_io #(.T(register_s)) unregistered_hs (.*);
    hs_replace_data hs_replace_data (
        .flw_hs(flw_hs),
        .ldr_hs(unregistered_hs),
        .data_i(unregistered)
    );

    hs_io #(.T(register_s)) register_hs (.*);
    hs_register hs_register_data (
        .flw_hs(unregistered_hs),
        .ldr_hs(register_hs)
    );

    wire  valid = register_hs.ldrv.req;
    wire  last = register_hs.ldrv.last;

    logic valid_raised;
    _hs_monostable _hs_monostable (
        .clk     (clk),
        .clk_en  (clk_en),
        .sync_rst(sync_rst),
        .sense   (valid),
        .mono    (valid_raised)
    );
    wire   fresh_data = valid_raised || (valid && register_hs.prev_flag.good);

    mask_t pending_reg;
    mask_t pending_clr;
    _hs_sr_vector #(
        .Width          (Handshakes),
        .PrioritizeClear(1'b1)
    ) _hs_sr_vector (
        .clk       (clk),
        .clk_en    (clk_en),
        .sync_rst  (sync_rst),
        .set_i     (register_hs.data.mask),
        .set_en_i  (fresh_data),
        .clear_i   (pending_clr),
        .clear_en_i(1'b1),
        .vector_o  (pending_reg)
    );

    mask_t pending;
    mask_t ldr_not_ready;
    assign pending = fresh_data ? register_hs.data.mask : pending_reg;
    always_comb begin
        unique case (register_hs.state)
            hs::READY, hs::PROBE, hs::MULTI: begin
                register_hs.fdrv.ack = ((pending & (~pending_clr)) == '0) && (register_hs.state != hs::BLOCK);
            end
            hs::BLOCK: begin
                register_hs.fdrv.ack = |ldr_not_ready;
            end
        endcase
    end

    genvar i;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_connect_leaders
            hs::lctl_s ldr_lctl;
            `HS_DRIVE_LDR(ldr_hs[i], ldr_lctl)
            always_comb begin
                ldr_hs[i].data   = `HS_CAST(ldr_hs[i], register_hs.data.data);
                ldr_lctl.start   = pending[i] && valid;
                ldr_lctl.pause   = !(pending[i] && valid);
                ldr_lctl.close   = last;
                ldr_lctl.abort   = 1'b0;
                ldr_not_ready[i] = pending[i] || (ldr_hs[i].state != hs::READY);
                pending_clr[i]   = ldr_hs[i].flag.good;
            end
        end
    endgenerate

endmodule : hs_demux_mask_new
