`include "hs_macro.sv"
module hs_sync #(
    parameter integer           Handshakes = 2,
    parameter hs::sync_policy_e SyncPolicy = hs::UndefinedSync
) (
    input  [Handshakes-1:0][$bits(hs::fprobe_s)-1:0] fprobes_i,
    output [Handshakes-1:0][  $bits(hs::fdrv_s)-1:0] fdrvs_o,

    input  hs::lprobe_s lprobe_i,
    output hs::ldrv_s   ldrv_o
);
    initial must_define_sync_policy : assert (SyncPolicy != hs::UndefinedSync);

    typedef logic [Handshakes-1:0] mask_t;
    genvar g;
    generate
        mask_t reqs_i, lasts_i;
        mask_t block_mask;
        mask_t ignore_req;

        wire   some_blockers = |block_mask;

        for (g = 0; g < Handshakes; g = g + 1) begin : g_connect
            hs::fprobe_s fprobe_g;
            assign fprobe_g      = fprobes_i[g];
            assign reqs_i[g]     = fprobe_g.req;
            assign lasts_i[g]    = fprobe_g.last;
            assign block_mask[g] = fprobe_g.state == hs::BLOCK;

            logic advance_flw;
            always_comb begin
                mask_t advance_mask;
                advance_mask    = reqs_i | ignore_req;
                advance_mask[g] = 1'b1;  // we don't care about our own req. avoid circular logic.
                advance_flw     = lprobe_i.ack && (&advance_mask);
            end

            hs::fctl_s fctl_g;
            case (SyncPolicy)
                hs::NoFrameSync: begin
                    assign ignore_req[g] = 1'b0;
                    always_comb begin
                        fctl_g.ready = advance_flw;
                        fctl_g.pause = !advance_flw;
                        fctl_g.block = 1'b0;
                    end
                end
                hs::Truncate: begin
                    assign ignore_req[g] = lprobe_i.state == hs::BLOCK || some_blockers;
                    always_comb begin
                        mask_t local_block_mask;
                        logic  all_partners_blocking;
                        local_block_mask      = block_mask;
                        local_block_mask[g]   = 1'b1;
                        all_partners_blocking = &local_block_mask;

                        fctl_g.ready          = advance_flw;
                        fctl_g.pause          = !advance_flw;
                        fctl_g.block          = (lprobe_i.state == hs::BLOCK) || !all_partners_blocking;
                    end
                end
                hs::FrameSync: begin
                    assign ignore_req[g] = (lprobe_i.state == hs::BLOCK) || (fprobe_g.state == hs::BLOCK);
                    always_comb begin
                        fctl_g.ready = advance_flw;
                        fctl_g.pause = !advance_flw;
                        fctl_g.block = lprobe_i.state != hs::READY;
                    end
                end
                default:
                begin
                    assign ignore_req[g] = 1'b0;
                    assign fctl_g        = '0;
                end
            endcase
            assign fdrvs_o[g] = hs::drive_flw(fprobe_g.state, fctl_g);
        end
        always_comb begin : comb_ldrv
            ldrv_o.req = (|(reqs_i & (~ignore_req))) && (&(reqs_i | ignore_req));
            unique case (SyncPolicy)
                hs::NoFrameSync: begin
                    ldrv_o.last = 1'b0;
                end
                hs::Truncate: begin
                    logic first_last;
                    logic abort, exit;
                    abort       = |(lasts_i & ~reqs_i);
                    exit        = (|lasts_i) && (&reqs_i);
                    first_last  = (abort || exit) && !some_blockers;
                    ldrv_o.last = first_last;
                end
                hs::FrameSync: begin
                    logic final_last;
                    final_last  = &(lasts_i | block_mask);
                    ldrv_o.last = final_last;
                end
            endcase
        end
    endgenerate

endmodule : hs_sync
