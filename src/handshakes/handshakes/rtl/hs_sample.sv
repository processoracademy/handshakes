`include "hs_macro.sv"
module hs_sample #(
    parameter integer Handshakes = 2
) (
    hs_io.flw flw_hs    [Handshakes],
    hs_io.flw request_hs,
    hs_io.ldr ldr_hs
);
    wire clk = ldr_hs.clk;
    wire clk_en = ldr_hs.clk_en;
    wire sync_rst = ldr_hs.sync_rst;

    `HS_ASSERT_H(flw_hs[0], ldr_hs)

    localparam SelWidth = (Handshakes > 1) ? $clog2(Handshakes) : 1;

    typedef logic [ldr_hs.W-1:0] data_t;

    typedef logic [SelWidth-1:0] sel_t;
    typedef logic [Handshakes-1:0] mask_t;

    `HS_ASSERT_T(request_hs, sel_t)

    mask_t sample_req;
    data_t sample_data[Handshakes];

    genvar g;
    generate
        for (g = 0; g < Handshakes; g = g + 1) begin : g_connect
            wire selected = request_hs.data == sel_t'(g);
            wire blocking = (ldr_hs.state == hs::BLOCK) || (flw_hs[g].state == hs::BLOCK);

            assign sample_data[g]     = data_t'(flw_hs[g].data);
            assign sample_req[g]      = selected && flw_hs[g].ldrv.req && !blocking;
            assign flw_hs[g].fdrv.ack = selected && internal_0_hs.ldrv.req && ldr_hs.fdrv.ack && !blocking;
        end
    endgenerate

    hs_io #(.T(data_t)) internal_0_hs (.*);
    data_t data;
    assign data = sample_data[request_hs.data];
    hs_replace_data hs_replace_data_request (
        .flw_hs(request_hs),
        .ldr_hs(internal_0_hs),
        .data_i(data)
    );
    logic req;
    assign req = sample_req[request_hs.data];
    hs::fctl_s fctl;
    assign fctl.ready = req;
    assign fctl.pause = !req;
    assign fctl.block = 1'b0;
    hs_io #(.T(data_t)) internal_1_hs (.*);
    hs_override_fctl hs_override_fctl (
        .flw_hs(internal_0_hs),
        .ldr_hs(internal_1_hs),
        .fctl_i(fctl)
    );
    hs_replace_data hs_replace_data_out (
        .flw_hs(internal_1_hs),
        .ldr_hs(ldr_hs),
        .data_i(type (ldr_hs.data)'(internal_1_hs.data))
    );

endmodule : hs_sample
