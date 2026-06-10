module hs_buffer (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    initial $warning("hs_buffer uses deprecated abort-preserving behaviour! Use hs_register instead.");
    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    `HS_ASSERT_H(flw_hs, ldr_hs)

    logic valid;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            valid <= 1'b0;
        end
        else if (clk_en) begin
            if (flw_hs.flag.good) begin
                ldr_hs.data <= flw_hs.data;
                valid       <= 1'b1;
            end
            else if (ldr_hs.flag.good) begin
                valid <= 1'b0;
            end
        end
    end

    logic last;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            last <= 1'b0;
        end
        if (clk_en) begin
            if (flw_hs.flag.exit) begin
                last <= 1'b1;
            end
            else if (ldr_hs.flag.exit) begin
                last <= 1'b0;
            end
        end
    end

    always_comb begin
        unique case (flw_hs.state)
            hs::READY, hs::PROBE, hs::MULTI: begin
                flw_hs.fdrv.ack = ldr_hs.fdrv.ack || !valid;  // make sure to ack on an empty buffer
            end
            hs::BLOCK: begin
                flw_hs.fdrv.ack = ldr_hs.state != hs::READY;
            end
        endcase
    end

    hs::lctl_s lctl;
    assign ldr_hs.ldrv = hs::drive_ldr(ldr_hs.state, lctl);
    assign lctl.start  = valid;
    assign lctl.pause  = !valid;
    assign lctl.close  = last && valid;
    assign lctl.abort  = last && !valid;

endmodule : hs_buffer
