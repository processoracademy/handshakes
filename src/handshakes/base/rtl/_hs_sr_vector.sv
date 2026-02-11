module _hs_sr_vector #(
    parameter integer Width           = 5,
    parameter bit     PrioritizeClear = 1'b0
) (
    input  logic             clk,
    input  logic             clk_en,
    input  logic             sync_rst,
    input  logic [Width-1:0] set_i,
    input  logic             set_en_i,
    input  logic [Width-1:0] clear_i,
    input  logic             clear_en_i,
    output logic [Width-1:0] vector_o
);

    wire [Width-1:0] next_set = set_en_i ? set_i : '0;
    wire [Width-1:0] next_clr = clear_en_i ? clear_i : '0;
    wire [Width-1:0] next_vector;
    generate
        if (PrioritizeClear) begin : g_clr_priority
            assign next_vector = (vector_o | next_set) & ~next_clr;
        end
        else begin : g_set_priority
            assign next_vector = (vector_o & ~next_clr) | next_set;
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (sync_rst) begin
            vector_o <= '0;
        end
        else if (clk_en) begin
            vector_o <= next_vector;
        end
    end

endmodule
