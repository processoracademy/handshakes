`include "hs_macro.sv"
module hs_serialize #(
    parameter integer unsigned WideW     = 0,
    parameter logic            BigEndian = 1'b0
) (
           hs_io.ldr                                                         narrow_hs,
    input  logic        [          (WideW/narrow_hs.W)-1:0][narrow_hs.W-1:0] data_i,
    input  logic        [$clog2((WideW/narrow_hs.W)+1)-1:0]                  length_i,
    input  hs::fprobe_s                                                      fprobe_i,
    output hs::fdrv_s                                                        fdrv_o
);
    wire clk = narrow_hs.clk;
    wire clk_en = narrow_hs.clk_en;
    wire sync_rst = narrow_hs.sync_rst;

    initial begin
        assert ((WideW / narrow_hs.W) * narrow_hs.W == WideW)
        else $fatal(1, "wide_hs width %0d must be a multiple of narrow_hs width %0d", WideW, narrow_hs.W);
        assert (WideW > narrow_hs.W)
        else $fatal(1, "wide_hs width %0d must be greater than narrow_hs width %0d", WideW, narrow_hs.W);
    end

    localparam integer Slices = WideW / narrow_hs.W;
    typedef logic [$clog2(Slices)-1:0] ptr_t;
    typedef type (data_i) wide_t;
    typedef type (length_i) length_t;

    typedef struct packed {
        wide_t   data;
        length_t length;
    } wide_s;

    hs_io #(.T(wide_s)) wide_hs (.*);
    assign wide_hs.ldrv.req    = fprobe_i.req;
    assign wide_hs.ldrv.last   = fprobe_i.last;
    assign fdrv_o.ack          = wide_hs.fdrv.ack;
    assign wide_hs.data.data   = data_i;
    assign wide_hs.data.length = length_i;

    hs_io #(.T(wide_s)) filtered_hs (.*);
    wire length_gt_0 = wide_hs.data.length > length_t'(0);
    hs_filter hs_filter_zero_length (
        .flw_hs(wide_hs),
        .ldr_hs(filtered_hs),
        .pass_i(length_gt_0),
        .drop_o()
    );

    hs_io #(.T(wide_s)) register_hs (.*);
    hs_register hs_register (
        .flw_hs(filtered_hs),
        .ldr_hs(register_hs)
    );

    wire  valid = register_hs.ldrv.req;
    wire  last = register_hs.ldrv.last;

    ptr_t ptr;

    localparam length_t WordsMax = length_t'(Slices);
    localparam ptr_t PtrReset = BigEndian ? ptr_t'(WordsMax - length_t'(1)) : '0;
    wire ptr_end = ptr == (BigEndian ? ptr_t'(WordsMax - register_hs.data.length) : ptr_t'(register_hs.data.length - length_t'(1)));

    always_comb begin
        unique case (register_hs.state)
            hs::READY, hs::PROBE, hs::MULTI: begin
                register_hs.fdrv.ack = ptr_end && narrow_hs.fdrv.ack;
            end
            hs::BLOCK: begin
                register_hs.fdrv.ack = narrow_hs.state != hs::READY;
            end
        endcase
    end

    ptr_t ptr_next;
    always_comb begin
        if (BigEndian) begin
            ptr_next = ptr_end ? PtrReset : ptr - ptr_t'(1);
        end
        else begin
            ptr_next = ptr_end ? PtrReset : ptr + ptr_t'(1);
        end
    end

    always_ff @(posedge clk) begin
        if (sync_rst || (clk_en && narrow_hs.flag.done)) begin
            ptr <= PtrReset;
        end
        else if (clk_en) begin
            if (narrow_hs.flag.good) begin
                ptr <= ptr_next;
            end
        end
    end

    hs::lctl_s lctl;
    assign narrow_hs.ldrv = hs::drive_ldr(narrow_hs.state, lctl);
    assign narrow_hs.data = `HS_CAST(narrow_hs, register_hs.data.data[ptr]);
    assign lctl.start     = valid;
    assign lctl.pause     = !valid;
    assign lctl.close     = ptr_end && last && valid;
    assign lctl.abort     = 1'b0;

endmodule : hs_serialize

