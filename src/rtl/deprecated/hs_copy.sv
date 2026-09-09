module hs_copy #(
    parameter integer Width = 8
) (
    input  logic                      clk,
    input  logic                      clk_en,
    input  logic                      sync_rst,
    input  logic                      copy_en_i,
    input  logic                      src_good_i,
    input  logic unsigned [Width-1:0] src_data_i,
    input  logic                      dest_good_i,
    output hs::fctl_s                 src_fctl_o,
    output hs::lctl_s                 dest_lctl_o,
    output logic unsigned [Width-1:0] dest_data_o
);
    initial $warning("hs_copy is deprecated!");

    typedef logic unsigned [Width-1:0] data_t;

    logic src_data_valid, src_pending;
    wire clear = sync_rst || !copy_en_i;
    always_ff @(posedge clk) begin
        if (clear) begin
            src_pending <= 1'b0;
        end
        else if (clk_en) begin
            src_pending <= src_data_valid && !dest_good_i;
        end
    end

    data_t src_data_reg;
    wire   src_data_write_en = clk_en && src_good_i;
    always_ff @(posedge clk) begin
        if (src_data_write_en) begin
            src_data_reg <= src_data_i;
        end
    end

    assign src_data_valid = src_good_i || src_pending;

    assign dest_data_o    = src_good_i ? src_data_i : src_data_reg;
    assign src_fctl_o     = src_pending ? hs::FctlPauseBlocking : hs::FctlReady;
    assign dest_lctl_o    = src_data_valid ? hs::LctlStart : hs::LctlPause;

endmodule : hs_copy
