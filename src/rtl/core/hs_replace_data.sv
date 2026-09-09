`include "hs_macro.sv"
module hs_replace_data (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs,
    input type(ldr_hs.data) data_i
);
    assign ldr_hs.ldrv = flw_hs.ldrv;
    assign ldr_hs.data = data_i;
    assign flw_hs.fdrv = ldr_hs.fdrv;
endmodule
