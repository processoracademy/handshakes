`include "hs_macro.sv"
module hs_alternate (
    hs_io.flw flw_a_hs,
    hs_io.flw flw_b_hs,
    hs_io.ldr ldr_a_hs,
    hs_io.ldr ldr_b_hs
);

    wire clk = flw_a_hs.clk;
    wire clk_en = flw_a_hs.clk_en;
    wire sync_rst = flw_a_hs.sync_rst;

    `HS_ASSERT_H(flw_a_hs, ldr_a_hs)
    `HS_ASSERT_H(flw_b_hs, ldr_b_hs)

    typedef enum {
        A,
        B
    } port_e;

    hs_io flw_hs[2] (.*);
    hs_io ldr_hs[2] (.*);

    hs_replace_data hs_replace_data_flw_a (
        .flw_hs(flw_a_hs),
        .ldr_hs(flw_hs[A]),
        .data_i(1'b0)
    );
    hs_replace_data hs_replace_data_flw_b (
        .flw_hs(flw_b_hs),
        .ldr_hs(flw_hs[B]),
        .data_i(1'b0)
    );

    hs_alternate_generic #(
        .Handshakes(2)
    ) hs_alternate_generic (
        .flw_hs(flw_hs),
        .ldr_hs(ldr_hs)
    );

    hs_replace_data hs_replace_data_ldr_a (
        .flw_hs(ldr_hs[A]),
        .ldr_hs(ldr_a_hs),
        .data_i(flw_a_hs.data)
    );
    hs_replace_data hs_replace_data_ldr_b (
        .flw_hs(ldr_hs[B]),
        .ldr_hs(ldr_b_hs),
        .data_i(flw_b_hs.data)
    );

endmodule
