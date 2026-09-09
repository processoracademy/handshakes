`include "hs_macro.sv"
module hs_iterate (
           hs_io.ldr                        iterator_hs,
    input  hs::fprobe_s                     fprobe_i,
    output hs::fdrv_s                       fdrv_o,
    input  logic        [iterator_hs.W-1:0] from_i,
    input  logic        [iterator_hs.W-1:0] to_i
);
    wire clk = iterator_hs.clk;
    wire clk_en = iterator_hs.clk_en;
    wire sync_rst = iterator_hs.sync_rst;

    typedef type (from_i) iterator_t;

    typedef struct packed {
        iterator_t from;
        iterator_t       to;
    } register_s;
    hs_io #(.T(register_s)) flw_hs (.*);
    assign flw_hs.ldrv.req  = fprobe_i.req;
    assign flw_hs.ldrv.last = fprobe_i.last;
    assign fdrv_o           = flw_hs.fdrv;
    assign flw_hs.data.from = from_i;
    assign flw_hs.data.to   = to_i;
    hs_io #(.T(register_s)) register_hs (.*);
    hs_register hs_register (
        .flw_hs(flw_hs),
        .ldr_hs(register_hs)
    );

    logic      next;
    hs::fctl_s fctl;
    assign register_hs.fdrv = hs::drive_flw(register_hs.state, fctl);
    assign fctl.ready       = next;
    assign fctl.pause       = !next;
    assign fctl.block       = 1'b0;

    wire iterator_end = iterator_t'(iterator_hs.data) == register_hs.data.to;
    assign next = (iterator_hs.flag.good && iterator_end) || !register_hs.ldrv.req;

    iterator_t iter, iter_fwd;
    logic pending;
    assign iter_fwd = pending ? register_hs.data.from : iter;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            pending <= 1'b1;
        end
        else if (clk_en) begin
            if (iterator_hs.flag.good) begin
                iter    <= iter_fwd + iterator_t'(1);
                pending <= iterator_end;
            end
            else if (!register_hs.ldrv.req) begin
                pending <= 1'b1;
            end
        end
    end

    hs::lctl_s lctl;
    assign iterator_hs.ldrv = hs::drive_ldr(iterator_hs.state, lctl);
    assign lctl.start       = register_hs.ldrv.req;
    assign lctl.pause       = !register_hs.ldrv.req;
    assign lctl.close       = register_hs.ldrv.last && iterator_end;
    assign lctl.abort       = 1'b0;
    assign iterator_hs.data = `HS_CAST(iterator_hs, iter_fwd);

endmodule : hs_iterate

