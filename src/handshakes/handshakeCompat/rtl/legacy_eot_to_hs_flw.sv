`include "hs_macro.sv"
module legacy_eot_to_hs_flw (
           hs_io.flw     flw_hs,
    output logic         req_o,
    input  logic         ack_i,
    output logic         eot_o,
    output type(flw_hs.data) data_o
);
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;
    
    typedef logic [flw_hs.W-1:0] data_t;
    hs_io #(.T(data_t)) internal_0_hs (.*);
    hs_io #(.T(data_t)) internal_1_hs (.*);
    hs_replace_data hs_replace_data (
        .flw_hs(flw_hs),
        .ldr_hs(internal_0_hs),
        .data_i(data_t'(flw_hs.data))
    );
    hs_absorb_aborts hs_absorb_aborts (
        .flw_hs(internal_0_hs),
        .ldr_hs(internal_1_hs)
    );

    assign internal_1_hs.fdrv.ack = ack_i && (internal_1_hs.state != hs::BLOCK);
    assign eot_o  = internal_1_hs.ldrv.last;  // We have guaranteed no aborts so this should map correctly.
    assign req_o  = internal_1_hs.ldrv.req;
    assign data_o = type(flw_hs.data)'(internal_1_hs.data);

endmodule : legacy_eot_to_hs_flw
