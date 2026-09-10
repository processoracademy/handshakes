`include "hs_macro.sv"
module legacy_eot_to_hs_ldr (
           hs_io.ldr                ldr_hs,
    input  logic                    req_i,
    output logic                    ack_o,
    input  logic                    eot_i,
    input  logic     [ldr_hs.W-1:0] data_i
);

    hs::lctl_s ldr_lctl;
    `HS_DRIVE_LDR(ldr_hs, ldr_lctl)
    assign ldr_lctl.start = req_i;
    assign ldr_lctl.pause = !req_i;
    assign ldr_lctl.close = eot_i;

    assign ldr_hs.data    = `HS_CAST(ldr_hs, data_i);
    assign ack_o          = ldr_hs.fdrv.ack && (ldr_hs.state != hs::BLOCK);

endmodule : legacy_eot_to_hs_ldr
