`include "hs_macro.sv"
module hs_serialize #(
    parameter logic BigEndian    = 1'b0,
    parameter logic AbsorbAborts = 1'b0
) (
    hs_io.flw wide_hs,
    hs_io.ldr narrow_hs
);
    wire clk = wide_hs.clk;
    wire clk_en = wide_hs.clk_en;
    wire sync_rst = wide_hs.sync_rst;

    initial begin
        assert ((wide_hs.W / narrow_hs.W) * narrow_hs.W == wide_hs.W)
        else $fatal(1, "wide_hs width %0d must be a multiple of narrow_hs width %0d", wide_hs.W, narrow_hs.W);
        assert (wide_hs.W > narrow_hs.W)
        else $fatal(1, "wide_hs width %0d must be greater than narrow_hs width %0d", wide_hs.W, narrow_hs.W);
    end

    localparam integer Slices = wide_hs.W / narrow_hs.W;
    typedef logic [$clog2(Slices)-1:0] ptr_t;
    typedef logic [Slices-1:0][narrow_hs.W-1:0] wide_t;

    hs_io #(.T(wide_t)) sliced_hs (.*);
    hs_replace_data hs_replace_data_sliced (
        .flw_hs(wide_hs),
        .ldr_hs(sliced_hs),
        .data_i(wide_t'(wide_hs.data))
    );

    hs_io #(.T(wide_t)) register_hs (.*);
    hs_register #(
        .AbsorbAborts(AbsorbAborts)
    ) hs_register (
        .flw_hs(sliced_hs),
        .ldr_hs(register_hs)
    );

    wire  valid = register_hs.ldrv.req;
    wire  last = register_hs.ldrv.last;

    ptr_t ptr;

    localparam ptr_t PtrReset = BigEndian ? ptr_t'(Slices - 1) : '0;
    wire ptr_end = ptr == (BigEndian ? '0 : ptr_t'(Slices - 1));

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
    assign narrow_hs.data = `HS_CAST(narrow_hs, register_hs.data[ptr]);
    assign lctl.start     = valid;
    assign lctl.pause     = !valid;
    assign lctl.close     = ptr_end && last && valid;
    assign lctl.abort     = last && !valid;

endmodule : hs_serialize

