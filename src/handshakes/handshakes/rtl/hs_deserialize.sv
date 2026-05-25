`include "hs_macro.sv"
module hs_deserialize #(
    parameter integer unsigned WideW        = 0,
    parameter logic            BigEndian    = 1'b0,
    parameter logic            AbsorbAborts = 1'b0
) (
           hs_io.flw                                                         narrow_hs,
    output logic        [          (WideW/narrow_hs.W)-1:0][narrow_hs.W-1:0] data_o,
    output logic        [$clog2((WideW/narrow_hs.W)+1)-1:0]                  length_o,
    input  hs::lprobe_s                                                      lprobe_i,
    output hs::ldrv_s                                                        ldrv_o
);
    wire clk = narrow_hs.clk;
    wire clk_en = narrow_hs.clk_en;
    wire sync_rst = narrow_hs.sync_rst;

    initial begin
        assert ((WideW / narrow_hs.W) * narrow_hs.W == WideW)
        else $fatal(1, "Parameter WideW %0d must be a multiple of narrow_hs width %0d", WideW, narrow_hs.W);
        assert (WideW > narrow_hs.W)
        else $fatal(1, "Parameter WideW %0d must be greater than narrow_hs width %0d", WideW, narrow_hs.W);
    end

    localparam integer Slices = WideW / narrow_hs.W;
    typedef logic [$clog2(Slices)-1:0] ptr_t;
    typedef type (length_o) length_t;

    ptr_t ptr;

    localparam length_t WordsMax = length_t'(Slices);
    localparam ptr_t PtrReset = BigEndian ? ptr_t'(Slices - 1) : '0;
    wire     ptr_end = ptr == (BigEndian ? '0 : ptr_t'(Slices - 1));

    ptr_t    ptr_next;
    length_t words_next;
    always_comb begin
        if (BigEndian) begin
            ptr_next = ptr_end ? PtrReset : ptr - ptr_t'(1);
        end
        else begin
            ptr_next = ptr_end ? PtrReset : ptr + ptr_t'(1);
        end
        words_next = (length_o == WordsMax) ? length_t'(1) : (length_o + length_t'(1));
    end

    hs::flag_s ldr_flag;
    assign ldr_flag = hs::get_flags(ldrv_o.req, lprobe_i.ack, ldrv_o.last, lprobe_i.state);
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            ptr      <= PtrReset;
            length_o <= '0;
        end
        else if (clk_en) begin
            if (narrow_hs.flag.good) begin
                ptr         <= ptr_next;
                length_o    <= words_next;
                data_o[ptr] <= narrow_hs.data;
            end
            else if (ldr_flag.good) begin
                // Empty if output is ack'd without a new input ack on same cycle.
                length_o <= '0;
            end
        end
    end

    logic last;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            last <= 1'b0;
        end
        if (clk_en) begin
            if (narrow_hs.flag.exit) begin
                last <= 1'b1;
            end
            else if (ldr_flag.exit) begin
                last <= 1'b0;
            end
        end
    end

    always_comb begin
        unique case (narrow_hs.state)
            hs::READY, hs::PROBE, hs::MULTI: begin
                narrow_hs.fdrv.ack = (length_o != WordsMax) || lprobe_i.ack;
            end
            hs::BLOCK: begin
                narrow_hs.fdrv.ack = lprobe_i.state != hs::READY;
            end
        endcase
    end

    hs::lctl_s lctl;
    assign ldrv_o = hs::drive_ldr(lprobe_i.state, lctl);
    wire empty = (length_o == '0);
    wire full = (length_o == WordsMax) && (narrow_hs.ldrv.req || last || !AbsorbAborts);
    wire valid = full || (last && !empty);
    assign lctl.start = valid;
    assign lctl.pause = !valid;
    assign lctl.close = last && !empty;
    assign lctl.abort = last && empty;

endmodule : hs_deserialize

