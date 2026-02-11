`include "hs_macro.sv"
module hs_eat (
    hs_io.flw flw_hs
);
    initial $warning("hs_eat is deprecated! Do `assign flw_hs.fdrv = flw_hs.drive_flw(hs::FctlReady);` instead.");
    assign flw_hs.fdrv = flw_hs.drive_flw(hs::FctlReady);
endmodule : hs_eat
