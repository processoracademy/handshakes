/**
 * hs_arbiter.sv
 * 
 * bus_hs: signals for the active selected/masked handshake
 * mask_i: unfiltered handshake req signals from all leader-side handshake buses
 * mask_o: onehot mask for enabling the specified handshake bus_hs
 * 
 * Quinn Unger 03/July/2023
 */

`include "hs_macro.sv"
module hs_arbiter #(
    parameter       Handshakes       = 2,
    parameter logic ArbitrateLeaders = 1'b0
) (
           hs_io                  bus_hs,
    input  logic [Handshakes-1:0] mask_i,
    output logic [Handshakes-1:0] mask_o
);
    // reference bus_hs' clock
    logic clk, clk_en, sync_rst;
    assign clk      = bus_hs.clk;
    assign clk_en   = bus_hs.clk_en;
    assign sync_rst = bus_hs.sync_rst;

    logic bus_is_free;
    _hs_round_robin #(
        .Width(Handshakes)
    ) _hs_round_robin (
        .clk      (clk),
        .clk_en   (clk_en),
        .sync_rst (sync_rst),
        .advance_i(bus_is_free),
        .mask_i   (mask_i),
        .mask_o   (mask_o),
        .index_o  ()
    );
    always_comb begin
        if (ArbitrateLeaders) begin
            bus_is_free = bus_hs.flag.done || !bus_hs.flag.live || !(|mask_o);
        end
        else begin
            // We expect the bus to be ack'd immediately. Move on otherwise.
            bus_is_free = !hs::flw_active(bus_hs.next_state) || !(|mask_o);
        end
    end

endmodule
