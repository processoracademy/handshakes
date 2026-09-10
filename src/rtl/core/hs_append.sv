`include "hs_macro.sv"
module hs_append #(
    parameter integer Handshakes = 2
) (
    hs_io.flw flw_hs[Handshakes],
    hs_io.ldr ldr_hs
);
    wire clk = flw_hs[0].clk;
    wire clk_en = flw_hs[0].clk_en;
    wire sync_rst = flw_hs[0].sync_rst;

    `HS_ASSERT_H(flw_hs[0], ldr_hs)

    typedef logic [ldr_hs.W-1:0] data_t;

    localparam integer IdxWidth = (Handshakes > 1) ? $clog2(Handshakes) : 1;
    typedef logic [IdxWidth-1:0] hs_idx_t;
    typedef logic [Handshakes-1:0] mask_t;

    mask_t req;
    mask_t ack;
    mask_t last;
    mask_t exit;
    data_t data [Handshakes];
    genvar g;
    generate
        for (g = 0; g < Handshakes; g = g + 1) begin : g_dereference
            assign req[g]             = flw_hs[g].ldrv.req;
            assign last[g]            = flw_hs[g].ldrv.last;
            assign exit[g]            = flw_hs[g].flag.exit;
            assign data[g]            = data_t'(flw_hs[g].data);
            assign flw_hs[g].fdrv.ack = ack[g];
        end
    endgenerate

    hs_idx_t sel, sel_next;
    logic retire, retire_next;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            sel    <= hs_idx_t'(0);
            retire <= 1'b0;
        end
        else if (clk_en) begin
            sel    <= sel_next;
            retire <= retire_next;
        end
    end

    always_comb begin
        sel_next        = sel;
        retire_next     = retire;

        ack             = '0;
        ack[sel]        = ldr_hs.fdrv.ack;
        ldr_hs.ldrv.req = req[sel];
        ldr_hs.data     = `HS_CAST(ldr_hs, data[sel]);

        case (sel)
            default: begin
                ldr_hs.ldrv.last = 1'b0;
                sel_next         = exit[sel] ? (sel + hs_idx_t'(1)) : sel;
            end
            hs_idx_t'(Handshakes - 1): begin
                ldr_hs.ldrv.last = last[sel];
                sel_next         = ldr_hs.flag.done ? hs_idx_t'(0) : sel;
            end
        endcase
    end

endmodule : hs_append
