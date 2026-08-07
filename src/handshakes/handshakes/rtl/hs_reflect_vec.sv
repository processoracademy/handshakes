`include "hs_macro.sv"
module hs_reflect_vec #(
    parameter integer Handshakes = 2
)(
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);

    genvar i;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_replace_data
            `HS_ASSERT_H(flw_hs[i], ldr_hs[i])
            hs_replace_data hs_replace_data (
                .flw_hs(flw_hs[i]),
                .ldr_hs(ldr_hs[i]),
                .data_i(flw_hs[i].data)
            );
        end
    endgenerate

endmodule : hs_reflect_vec
