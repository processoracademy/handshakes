`include "hs_macro.sv"
module hs_append (
    hs_io.flw head_hs,
    hs_io.flw tail_hs,
    hs_io.ldr appended_hs
);
    wire clk = head_hs.clk;
    wire clk_en = head_hs.clk_en;
    wire sync_rst = head_hs.sync_rst;

    `HS_ASSERT_H(appended_hs, tail_hs)
    `HS_ASSERT_H(appended_hs, head_hs)

    typedef logic [appended_hs.W-1:0] data_t;
    hs_io #(.T(data_t)) packed_hs[2] (.*);
    hs_replace_data hs_replace_data_head (
        .flw_hs(head_hs),
        .ldr_hs(packed_hs[0]),
        .data_i(data_t'(head_hs.data))
    );
    hs_replace_data hs_replace_data_tail (
        .flw_hs(tail_hs),
        .ldr_hs(packed_hs[1]),
        .data_i(data_t'(tail_hs.data))
    );
    hs_io #(.T(logic)) reset_hs (.*);
    `HS_DRIVE_LDR(reset_hs, hs::LctlIdle)
    assign reset_hs.data = '0;
    hs_io #(.T(data_t)) internal_hs (.*);
    hs_append_generic #(
        .Handshakes(2)
    ) hs_append_generic (
        .flw_hs  (packed_hs),
        .reset_hs(reset_hs),
        .ldr_hs  (internal_hs)
    );
    hs_replace_data hs_replace_data_appended (
        .flw_hs(internal_hs),
        .ldr_hs(appended_hs),
        .data_i(`HS_CAST(appended_hs, internal_hs.data))
    );

endmodule : hs_append
