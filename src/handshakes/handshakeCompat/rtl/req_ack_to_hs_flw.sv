`include "hs_macro.sv"
module req_ack_to_hs_flw (
           hs_io.flw         flw_hs,
    output logic             req_o,
    input  logic             ack_i,
    output type(flw_hs.data) data_o
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_DRIVE_FLW(flw_hs)
    assign flw_hs.fctl = ack_i ? hs::FctlReady : hs::FctlPause;
    assign req_o       = flw_hs.ldrv.req;
    assign data_o      = flw_hs.data;

endmodule : req_ack_to_hs_flw
