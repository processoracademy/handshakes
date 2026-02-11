`include "hs_macro.sv"
module hs_unframe (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs)

    assign ldr_hs.data      = flw_hs.data;
    assign ldr_hs.ldrv.req  = flw_hs.ldrv.req && (flw_hs.state != hs::BLOCK);
    assign ldr_hs.ldrv.last = 1'b0;
    assign flw_hs.fdrv.ack  = ldr_hs.fdrv.ack && (flw_hs.state != hs::BLOCK);

    assign ldr_hs.lctl      = '0;
    assign flw_hs.fctl      = '0;
endmodule : hs_unframe
