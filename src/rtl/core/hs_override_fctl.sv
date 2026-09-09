`include "hs_macro.sv"
module hs_override_fctl (
          hs_io.flw  flw_hs,
          hs_io.ldr  ldr_hs,
    input hs::fctl_s fctl_i
);

    `HS_ASSERT_H(flw_hs, ldr_hs)

    wire  clk = flw_hs.clk;
    wire  clk_en = flw_hs.clk_en;
    wire  sync_rst = flw_hs.sync_rst;

    logic unblock_pending;
    always_ff @(posedge clk) begin
        if (sync_rst || (clk_en && flw_hs.flag.done)) begin
            unblock_pending <= 1'b0;
        end
        else if (clk_en && fctl_i.block && ldr_hs.flag.done) begin
            unblock_pending <= 1'b1;
        end
    end

    always_comb begin
        unique case (flw_hs.state)
            hs::READY, hs::PROBE: begin
                flw_hs.fdrv.ack = ldr_hs.fdrv.ack && fctl_i.ready;
                ldr_hs.ldrv.req = flw_hs.ldrv.req && fctl_i.ready;
                ldr_hs.ldrv.last = (flw_hs.ldrv.last && fctl_i.ready) || (flw_hs.ldrv.last && !fctl_i.ready && !flw_hs.ldrv.req);
            end
            hs::MULTI: begin
                flw_hs.fdrv.ack = ldr_hs.fdrv.ack && !fctl_i.pause;
                ldr_hs.ldrv.req = flw_hs.ldrv.req && !fctl_i.pause;
                ldr_hs.ldrv.last = (flw_hs.ldrv.last && !fctl_i.pause) || (flw_hs.ldrv.last && fctl_i.pause && !flw_hs.ldrv.req);
            end
            hs::BLOCK: begin
                flw_hs.fdrv.ack  = (ldr_hs.fdrv.ack && !unblock_pending) || fctl_i.block;
                ldr_hs.ldrv.req  = 1'b0;
                ldr_hs.ldrv.last = 1'b0;
            end
        endcase
    end

    assign ldr_hs.data = flw_hs.data;

endmodule : hs_override_fctl
