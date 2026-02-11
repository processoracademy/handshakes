`include "hs_macro.sv"
module hs_alternate_generic #(
    parameter bit Bare       = 1'b0,
    parameter     Handshakes = 2
) (
    hs_io.flw flw_hs[Handshakes],
    hs_io.ldr ldr_hs[Handshakes]
);
    wire clk = flw_hs[0].clk;
    wire clk_en = flw_hs[0].clk_en;
    wire sync_rst = flw_hs[0].sync_rst;

    genvar i;

    // dereference the interface arrays
    logic [Handshakes-1:0] flw_req;
    logic [Handshakes-1:0] flw_ack;
    logic [Handshakes-1:0] flw_last;
    logic [Handshakes-1:0] ldr_req;
    logic [Handshakes-1:0] ldr_ack;
    logic [Handshakes-1:0] ldr_last;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_conn
            assign flw_req[i]          = flw_hs[i].ldrv.req;
            assign flw_hs[i].fdrv.ack  = flw_ack[i];
            assign flw_last[i]         = flw_hs[i].ldrv.last;
            assign flw_hs[i].fctl      = '0;  // We don't use fctl

            assign ldr_hs[i].ldrv.req  = ldr_req[i];
            assign ldr_ack[i]          = ldr_hs[i].fdrv.ack;
            assign ldr_hs[i].ldrv.last = ldr_last[i];
            assign ldr_hs[i].lctl      = '0;  // We don't use lctl

            if (!Bare) begin : g_conn_data
                assign ldr_hs[i].data = flw_hs[i].data;
            end

        end
    endgenerate

    // Mask off inactive handshake signals
    logic [Handshakes-1:0] mask;
    assign ldr_req  = flw_req & mask;
    assign flw_ack  = ldr_ack & mask;
    assign ldr_last = flw_last & mask;

    // setup common Bus for the arbiter's handshake tracking (view only the masked connection)
    hs_io bus (
        .clk     (clk),
        .clk_en  (clk_en),
        .sync_rst(sync_rst)
    );
    assign bus.ldrv.req  = |(flw_req & mask);
    assign bus.fdrv.ack  = |(ldr_ack & mask);
    assign bus.ldrv.last = |(flw_last & mask);
    assign bus.fctl      = '0;
    assign bus.lctl      = '0;

    hs_arbiter #(
        .Handshakes      (Handshakes),
        .ArbitrateLeaders(1'b1)
    ) hs_arbiter (
        .bus_hs(bus),
        .mask_i(flw_req),
        .mask_o(mask)
    );

endmodule : hs_alternate_generic
