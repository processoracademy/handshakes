`include "hs_macro.sv"
module hs_unblock (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    `HS_ASSERT_H(flw_hs, ldr_hs)
    assign ldr_hs.data      = flw_hs.data;
    assign ldr_hs.ldrv.req  = (ldr_hs.state == hs::BLOCK) ? 1'b0 : flw_hs.ldrv.req;
    assign ldr_hs.ldrv.last = flw_hs.ldrv.last;
    assign flw_hs.fdrv.ack  = (ldr_hs.state == hs::BLOCK) ? 1'b0 : ldr_hs.fdrv.ack;
endmodule : hs_unblock
