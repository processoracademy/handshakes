`include "hs_macro.sv"
/*
Module: hs_filter

Use pass_i to forward or drop data passing from flw_hs to ldr_hs.

Frames are preserved unless an entire frame is dropped from start to finish.

Ports:
    flw_hs - source data
    ldr_hs - filtered data
    pass_i - synchronous with <flw_hs> data, discards <flw_hs> transactions when set to 0.

--- SystemVerilog
// Example filter that keeps values that are greater than zero:
hs_filter is_greater_than_0 (
    .flw_hs(flw_hs),
    .ldr_hs(ldr_hs),
    .pass_i((flw_hs.data > 0))
);
---
*/
module hs_filter (
          hs_io.flw flw_hs,
          hs_io.ldr ldr_hs,
    input logic     pass_i
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs)

    logic valid;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            valid <= 1'b0;
        end
        else if (clk_en) begin
            if (flw_hs.flag.good && pass_i) begin
                ldr_hs.data <= flw_hs.data;
                valid       <= 1'b1;
            end
            else if (ldr_hs.flag.good) begin
                valid <= 1'b0;
            end
        end
    end

    logic last;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            last <= 1'b0;
        end
        if (clk_en) begin
            if (flw_hs.flag.exit && ((pass_i && !flw_hs.flag.term) || (ldr_hs.state != hs::READY) || valid)) begin
                last <= 1'b1;
            end
            else if (ldr_hs.flag.exit) begin
                last <= 1'b0;
            end
        end
    end

    always_comb begin
        unique case (flw_hs.state)
            hs::READY, hs::PROBE, hs::MULTI: begin
                flw_hs.fdrv.ack = ldr_hs.fdrv.ack || (!pass_i) || (!valid);  // make sure to ack on an empty buffer
            end
            hs::BLOCK: begin
                flw_hs.fdrv.ack = valid || (ldr_hs.state != hs::READY);
            end
        endcase
    end

    hs::lctl_s lctl;
    assign ldr_hs.ldrv = hs::drive_ldr(ldr_hs.state, lctl);
    wire ldr_valid = valid && ((pass_i && flw_hs.ldrv.req) || last);
    assign lctl.start = ldr_valid;
    assign lctl.pause = !ldr_valid;
    assign lctl.close = last && valid;
    assign lctl.abort = 1'b0;

endmodule : hs_filter
