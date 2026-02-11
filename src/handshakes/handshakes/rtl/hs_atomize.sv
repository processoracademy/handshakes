// Turn each handshake transaction into individual frames
`include "hs_macro.sv"
module hs_atomize (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs)

    assign ldr_hs.data      = flw_hs.data;
    assign ldr_hs.ldrv.req  = flw_hs.ldrv.req && (ldr_hs.state != hs::BLOCK);
    assign ldr_hs.ldrv.last = flw_hs.ldrv.req && (ldr_hs.state != hs::BLOCK);

    // Preserve blocking phase for the final flw word
    always_comb begin
        if (flw_hs.state == hs::BLOCK) begin
            flw_hs.fdrv.ack = ldr_hs.fdrv.ack && (ldr_hs.state == hs::BLOCK);
        end
        else begin
            flw_hs.fdrv.ack = ldr_hs.fdrv.ack && (ldr_hs.state != hs::BLOCK);
        end
    end

    assign ldr_hs.lctl = '0;
    assign flw_hs.fctl = '0;

endmodule : hs_atomize
