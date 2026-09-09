module _hs_monostable (
    input  clk,
    input  clk_en,
    input  sync_rst,
    input  sense,
    output mono
);
    reg sense_prev;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            sense_prev <= 1'b0;
        end
        else if (clk_en) begin
            sense_prev <= sense;
        end
    end
    assign mono = sense && !sense_prev;
endmodule : _hs_monostable
