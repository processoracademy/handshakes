`include "hs_macro.sv"
module hs_capture_on_rising_edge #(
    parameter logic WithForwarding = 1'b0
) (
    hs_io.ldr               ldr_hs,
    input logic             sense_i,
    input type(ldr_hs.data) data_i
);
    wire  clk = ldr_hs.clk;
    wire  clk_en = ldr_hs.clk_en;
    wire  sync_rst = ldr_hs.sync_rst;

    typedef logic [ldr_hs.W-1:0] data_t;

    logic mono;
    _hs_monostable _hs_monostable (
        .clk     (clk),
        .clk_en  (clk_en),
        .sync_rst(sync_rst),
        .sense   (sense_i),
        .mono    (mono)
    );

    `HS_DRIVE_LDR(ldr_hs)
    generate
        if (WithForwarding) begin : g_forwarded
            data_t buffer;
            always_ff @(posedge clk) begin
                if (clk_en && mono) begin
                    buffer <= data_i;
                end
            end
            assign ldr_hs.lctl.start = mono;
            assign ldr_hs.data       = mono ? data_i : `HS_CAST(ldr_hs, buffer);
        end
        else begin : g_not_forwarded
            logic start;
            always_ff @(posedge clk) begin
                if (sync_rst) begin
                    start <= 1'b0;
                end
                else if (clk_en) begin
                    start <= mono;
                    if (mono) begin
                        ldr_hs.data <= data_i;
                    end
                end
            end
            assign ldr_hs.lctl.start = start;
        end
    endgenerate

    assign ldr_hs.lctl.pause = 1'b0;
    assign ldr_hs.lctl.close = 1'b1;
    assign ldr_hs.lctl.abort = 1'b0;

endmodule : hs_capture_on_rising_edge
