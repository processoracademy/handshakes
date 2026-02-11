`include "hs_macro.sv"
// Add one word of latency in order to absorb aborts.
// This ensures that the hs frame always exits on valid data.
module hs_absorb_aborts (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
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

    assign flw_hs.fctl = '0;  // We are driving ack directly
    always_comb begin
        unique case (flw_hs.state)
            hs::READY, hs::PROBE, hs::MULTI: begin
                flw_hs.fdrv.ack = ldr_hs.fdrv.ack || !valid;  // make sure to ack on empty buffer
            end
            hs::BLOCK: begin
                flw_hs.fdrv.ack = ldr_hs.state != hs::READY;
            end
        endcase
    end

    `HS_DRIVE_LDR(ldr_hs)
    // req if we have registered an end-of-frame or we know another word is pending
    wire ldr_valid = valid && (flw_hs.ldrv.req || last);
    assign ldr_hs.lctl.start = ldr_valid;
    assign ldr_hs.lctl.pause = !ldr_valid;
    assign ldr_hs.lctl.close = valid && last;
    assign ldr_hs.lctl.abort = 1'b0;

endmodule : hs_absorb_aborts
