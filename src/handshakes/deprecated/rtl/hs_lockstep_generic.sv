module hs_lockstep_generic #(
    parameter integer Handshakes = 1,
    parameter logic   Blackhole  = 1'b0
) (
    hs_io.flw flw_hs[Handshakes],
    hs_io.ldr ldr_hs[Handshakes]
);
    initial $warning("hs_lockstep_generic is deprecated!");
    typedef logic [Handshakes-1:0] mask_t;
    mask_t raw_ack, raw_req;
    mask_t are_ready, are_multi, are_block;

    // handshake frames can't start until everyone is at hs::READY.
    wire ready_check = &(raw_req & raw_ack & are_ready);

    // multicycle handshakes that haven't completed must all progress in lock-step.
    wire multi_check = &(raw_req & raw_ack | ~are_multi);

    genvar i;
    generate
        for (i = 0; i < Handshakes; i = i + 1) begin : g_main
            assign ldr_hs[i].data = flw_hs[i].data;

            assign raw_ack[i]     = ldr_hs[i].fdrv.ack;
            assign raw_req[i]     = flw_hs[i].ldrv.req;

            assign are_ready[i]   = !hs::flw_active(flw_hs[i].state);
            assign are_multi[i]   = flw_hs[i].state == hs::MULTI;

            // Zero lctl/fctl as we are driving req/ack/last directly.
            assign flw_hs[i].fctl = '0;
            assign ldr_hs[i].lctl = '0;

            always_comb begin
                unique case (flw_hs[i].state)
                    hs::READY, hs::PROBE: begin
                        flw_hs[i].fdrv.ack  = ready_check;
                        ldr_hs[i].ldrv.req  = ready_check;
                        ldr_hs[i].ldrv.last = ready_check && flw_hs[i].ldrv.last;
                    end
                    hs::MULTI: begin
                        if(Blackhole&&!(&are_multi)) begin // Kill all remaining packets of the frame once one frame finishes.
                            flw_hs[i].fdrv.ack = 1'b1;  // Blindly consume all remaining data
                            ldr_hs[i].ldrv.req = 1'b0;  // Don't tell downstream about this
                            ldr_hs[i].ldrv.last = flw_hs[i].ldrv.last; // Trigger the flag.term condition once finished consuming.
                        end
                        else begin
                            flw_hs[i].fdrv.ack = multi_check;
                            ldr_hs[i].ldrv.req = multi_check;
                            ldr_hs[i].ldrv.last = (flw_hs[i].ldrv.last && multi_check)  // Normal flag.exit condition
                            || (flw_hs[i].ldrv.last && !flw_hs[i].ldrv.req);  // Abort flag.term condition
                        end
                    end
                    hs::BLOCK: begin
                        // pass-thru signalling here
                        flw_hs[i].fdrv.ack  = ldr_hs[i].fdrv.ack;
                        ldr_hs[i].ldrv.req  = 1'b0;
                        ldr_hs[i].ldrv.last = 1'b0;
                    end
                endcase
            end
        end
    endgenerate

endmodule : hs_lockstep_generic
