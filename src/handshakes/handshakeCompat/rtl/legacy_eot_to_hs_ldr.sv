`include "hs_macro.sv"
module legacy_eot_to_hs_ldr (
    hs_io.ldr                ldr_hs,
    input  logic             req_i,
    output logic             ack_o,
    input  logic             eot_i,
    input  type(ldr_hs.data) data_i
);

    `HS_DRIVE_LDR(ldr_hs)
    assign ldr_hs.lctl.start = req_i;
    assign ldr_hs.lctl.pause = !req_i;
    assign ldr_hs.lctl.close = eot_i;
    assign ldr_hs.lctl.abort = 1'b0;

    assign ldr_hs.data       = data_i;
    assign ack_o             = ldr_hs.fdrv.ack && (ldr_hs.state != hs::BLOCK);

endmodule : legacy_eot_to_hs_ldr
