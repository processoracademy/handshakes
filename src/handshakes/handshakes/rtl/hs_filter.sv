`include "hs_macro.sv"
module hs_filter (
           hs_io.flw flw_hs,
           hs_io.ldr ldr_hs,
    input  logic     pass_i,
    output logic     drop_o
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs)

    assign flw_hs.fctl = '0;
    assign ldr_hs.lctl = '0;
    always_comb begin
        unique case (ldr_hs.state)
            hs::BLOCK: flw_hs.fdrv.ack = (flw_hs.state == hs::BLOCK) && ldr_hs.fdrv.ack;
            default:   flw_hs.fdrv.ack = (flw_hs.state != hs::BLOCK) && (ldr_hs.fdrv.ack || !pass_i);
        endcase
    end
    assign ldr_hs.ldrv.req  = flw_hs.ldrv.req && pass_i;
    assign ldr_hs.ldrv.last = flw_hs.ldrv.last && (ldr_hs.ldrv.req || (ldr_hs.state != hs::READY));
    assign ldr_hs.data      = flw_hs.data;
    assign drop_o           = flw_hs.flag.good && !pass_i;

endmodule : hs_filter
