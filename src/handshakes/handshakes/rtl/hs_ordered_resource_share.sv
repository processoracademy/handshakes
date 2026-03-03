`include "hs_macro.sv"
module hs_ordered_resource_share #(
    parameter integer Ports           = 2,
    parameter integer TrackedRequests = 4
) (
    hs_io.flw request_port_hs    [Ports],
    hs_io.ldr response_port_hs   [Ports],
    hs_io.ldr tracked_request_hs,
    hs_io.flw tracked_response_hs
);
    wire clk = tracked_request_hs.clk;
    wire clk_en = tracked_request_hs.clk_en;
    wire sync_rst = tracked_request_hs.sync_rst;

    `HS_ASSERT_H(request_port_hs[0], tracked_request_hs)
    `HS_ASSERT_H(response_port_hs[0], tracked_response_hs)

    localparam integer PortWidth = (Ports > 1) ? $clog2(Ports) : 1;
    typedef logic [request_port_hs[0].W-1:0] request_t;
    typedef logic [tracked_response_hs.W-1:0] response_t;

    typedef logic [PortWidth-1:0] port_t;

    hs_io #(.T(request_t)) deref_req_port_hs[Ports] (.*);
    hs_io #(.T(response_t)) deref_resp_port_hs[Ports] (.*);
    genvar i;
    generate
        for (i = 0; i < Ports; i = i + 1) begin : g_handshake_type_dereference
            hs_replace_data hs_replace_data_req (
                .flw_hs(request_port_hs[i]),
                .ldr_hs(deref_req_port_hs[i]),
                .data_i(request_t'(request_port_hs[i].data))
            );
            hs_replace_data hs_replace_data_resp (
                .flw_hs(deref_resp_port_hs[i]),
                .ldr_hs(response_port_hs[i]),
                .data_i(response_t'(deref_resp_port_hs[i].data))
            );
        end
    endgenerate

    hs_io #(.T(request_t)) gated_request_hs (.*);
    port_t issued_port;
    hs_arbitrate_leaders #(
        .Leaders(Ports)
    ) hs_arbitrate_leaders_requests (
        .flw_hs(deref_req_port_hs),
        .ldr_hs(gated_request_hs),
        .addr  (issued_port),
        .mask  ()
    );

    hs_io #(.T(port_t)) tracked_port_0_hs (.*);
    hs_capture_on_rising_edge hs_capture_on_rising_edge (
        .ldr_hs (tracked_port_0_hs),
        .sense_i(gated_request_hs.flag.init),
        .data_i (issued_port)
    );

    // if port issue buffer is full, wait for it to clear.
    hs::fctl_s fctl;
    assign fctl.ready = 1'b1;
    assign fctl.pause = 1'b0;
    assign fctl.block = gated_request_hs.prev_flag.init || (tracked_port_0_hs.state != hs::READY);
    hs_io #(.T(request_t)) deref_tracked_req_hs (.*);
    hs_override_fctl hs_override_fctl (
        .flw_hs(gated_request_hs),
        .ldr_hs(deref_tracked_req_hs),
        .fctl_i(fctl)
    );
    hs_replace_data hs_replace_data_tracked_req (
        .flw_hs(deref_tracked_req_hs),
        .ldr_hs(tracked_request_hs),
        .data_i(type (tracked_request_hs.data)'(deref_tracked_req_hs.data))
    );

    hs_io #(.T(port_t)) tracked_port_1_hs (.*);
    hs_fifo #(
        .Depth(TrackedRequests)
    ) hs_fifo (
        .flw_hs(tracked_port_0_hs),
        .ldr_hs(tracked_port_1_hs)
    );

    hs_io #(.T(response_t)) retired_response_hs (.*);
    hs_sync #(
        .Handshakes(2),
        .SyncPolicy(hs::FrameSync)
    ) hs_sync (
        .fprobes_i({tracked_response_hs.fprobe, tracked_port_1_hs.fprobe}),
        .fdrvs_o  ({tracked_response_hs.fdrv, tracked_port_1_hs.fdrv}),
        .lprobe_i (retired_response_hs.lprobe),
        .ldrv_o   (retired_response_hs.ldrv)
    );
    assign retired_response_hs.data = response_t'(tracked_response_hs.data);

    hs_demux_index #(
        .Handshakes(Ports)
    ) hs_demux_index (
        .flw_hs (retired_response_hs),
        .ldr_hs (deref_resp_port_hs),
        .index_i(tracked_port_1_hs.data)
    );

endmodule : hs_ordered_resource_share
