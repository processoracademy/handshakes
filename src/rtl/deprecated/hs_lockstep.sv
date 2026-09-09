module hs_lockstep #(
    parameter logic Blackhole = 1'b0
) (
    hs_io.flw flw_a_hs,
    hs_io.flw flw_b_hs,
    hs_io.ldr ldr_a_hs,
    hs_io.ldr ldr_b_hs
);
    initial $warning("hs_lockstep is deprecated!");
    
    wire clk = flw_a_hs.clk;
    wire clk_en = flw_a_hs.clk_en;
    wire sync_rst = flw_a_hs.sync_rst;

    hs_io unsync_hs[2] (.*);
    hs_io sync_hs[2] (.*);

    hs_replace_data hs_replace_data_flw_a (
        .flw_hs(flw_a_hs),
        .ldr_hs(unsync_hs[0]),
        .data_i(1'b0)
    );
    hs_replace_data hs_replace_data_flw_b (
        .flw_hs(flw_b_hs),
        .ldr_hs(unsync_hs[1]),
        .data_i(1'b0)
    );

    hs_lockstep_generic #(
        .Handshakes(2),
        .Blackhole (Blackhole)
    ) hs_lockstep_generic (
        .flw_hs(unsync_hs),
        .ldr_hs(sync_hs)
    );

    hs_replace_data hs_replace_data_ldr_a (
        .flw_hs(sync_hs[0]),
        .ldr_hs(ldr_a_hs),
        .data_i(flw_a_hs.data)
    );
    hs_replace_data hs_replace_data_ldr_b (
        .flw_hs(sync_hs[1]),
        .ldr_hs(ldr_b_hs),
        .data_i(flw_b_hs.data)
    );

endmodule : hs_lockstep
