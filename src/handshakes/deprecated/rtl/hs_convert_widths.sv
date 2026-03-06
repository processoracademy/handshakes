/**
 * hs_convert_widths.sv
 * 
 * Converts between different interface widths, or acts as a decoupled buffer for same widths.
 * 
 * Widths are inferred from the handshake properties, no configuration is necessary 
 * as long as the handshake interfaces are defined with the widths you expect.
 * 
 * Data is moved assuming least significant bit/word is sent first.
 * 
 * Narrow words are not split up between wide word boundaries!
 * e.g. if the narrow width doesn't evenly divide into the wide width, the upper bits of the wide 
 * word are left unutilized, and the next fitting narrow word will be sent on the following wide.
 * This can be undesirable behaviour, so setting EnforceEvenFit will throw an error on size mismatch.
 * 
 * Quinn Unger 25/Oct/2023
**/

`include "hs_macro.sv"
module hs_convert_widths #(
    parameter logic EnforceEvenFit = 1'b0
) (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    initial $warning("hs_convert_widths is deprecated!");
    typedef enum {
        FollowerIsWider,
        LeaderIsWider,
        EqualWidth
    } wide_e;

    function integer ceil_div(integer a, integer b);
        return (a + b - 1) / b;
    endfunction : ceil_div
    
    localparam wide_e WidthTest = (flw_hs.W > ldr_hs.W) ? FollowerIsWider : (flw_hs.W < ldr_hs.W) ? LeaderIsWider : EqualWidth;
    localparam integer NarrowWidth = (WidthTest == FollowerIsWider) ? ldr_hs.W : flw_hs.W;
    localparam integer WideWidth = (WidthTest == FollowerIsWider) ? flw_hs.W : ldr_hs.W;

    localparam integer Entries = ceil_div(WideWidth, NarrowWidth);
    localparam integer BufWidth = Entries * NarrowWidth;
    localparam integer BufOversize = BufWidth - WideWidth;
    localparam integer PtrWidth = Entries > 1 ? $clog2(Entries) : 1;

`ifdef SIM_DEBUG
    generate
        if (EnforceEvenFit && (BufOversize > 0)) begin : g_enforce_even_fit_error
            $fatal(0, "flw_hs width (%0d) and ldr_hs width (%0d) do not divide evenly!", flw_hs.W, ldr_hs.W);
        end
    endgenerate
`endif

    typedef logic unsigned [PtrWidth-1:0] ptr_t;
    typedef logic unsigned [Entries-1:0][NarrowWidth-1:0] buf_t;
    typedef logic [ldr_hs.W-1:0] ldr_t;
    typedef logic [flw_hs.W-1:0] flw_t;

    typedef struct packed {
        ptr_t ptr;
        logic valid;
        logic init;
        logic last;
        logic block;
    } state_s;

    state_s state, state_next;

    logic clk, clk_en, sync_rst;
    assign clk      = flw_hs.clk;
    assign clk_en   = flw_hs.clk_en;
    assign sync_rst = flw_hs.sync_rst;

    flw_t flw_word;
    ldr_t ldr_word;

    `HS_DRIVE_FLW(flw_hs)

    assign flw_word          = flw_t'(flw_hs.data);
    assign flw_hs.fctl.ready = !state.valid;
    assign flw_hs.fctl.pause = state.valid;
    assign flw_hs.fctl.block = state.block;

    `HS_DRIVE_LDR(ldr_hs)

    assign ldr_hs.data = `HS_CAST(ldr_hs, ldr_word);
    always_comb begin
        ldr_hs.lctl.start = state.init && state.valid;
        ldr_hs.lctl.pause = !state.valid;
        unique case (WidthTest)
            FollowerIsWider: ldr_hs.lctl.close = state.last && state.valid && (state.ptr == ptr_t'(Entries - 1));
            default:         ldr_hs.lctl.close = (state.last && state.valid);
        endcase
        ldr_hs.lctl.abort = state.last && !state.valid;
    end

    logic ptr_inc, ptr_rst;
    logic valid_set, valid_clr;

    always_comb begin
        state_next.block = state.block;
        state_next.init  = state.init;
        state_next.last  = state.last;
        state_next.valid = state.valid;
        state_next.ptr   = ptr_rst ? ptr_t'(0) : (state.ptr + ptr_t'(ptr_inc));

        // block is high from flw_hs.flag.init until ldr_hs.flag.done
        if (ldr_hs.flag.done) begin
            state_next.block = 1'b0;
        end
        else if (flw_hs.flag.init) begin
            state_next.block = 1'b1;
        end

        // init needs to stay high from flw_hs.init to ldr_hs.init
        if (ldr_hs.flag.init) begin
            state_next.init = 1'b0;
        end
        else if (flw_hs.flag.init) begin
            state_next.init = 1'b1;
        end

        // last stays high from flw_hs.exit to ldr_hs.done
        if (ldr_hs.flag.done) begin
            state_next.last = 1'b0;
        end
        else if (flw_hs.flag.exit) begin
            state_next.last = 1'b1;
        end

        if (valid_clr) begin
            state_next.valid = 1'b0;
        end
        else if (valid_set) begin
            state_next.valid = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (sync_rst) begin
            state <= '0;
        end
        else if (clk_en) begin
            state <= state_next;
        end
    end

    generate
        case (WidthTest)
            FollowerIsWider: begin : g_wide_to_narrow
                // ptr increments on ldr_hs.flag.good, with reset on flw_hs.flag.good + wraparound logic.
                assign ptr_inc   = ldr_hs.flag.good;
                assign ptr_rst   = flw_hs.flag.good || (state.ptr == ptr_t'(Entries - 1));

                // valid is high from flw_hs.good until the final word has been read from the internal buffer
                assign valid_set = flw_hs.flag.good;
                assign valid_clr = ldr_hs.flag.good && (state.ptr == ptr_t'(Entries - 1));

                buf_t buffer;
                always_ff @(posedge clk) begin
                    if (clk_en && flw_hs.flag.good) begin
                        buffer <= BufWidth'(flw_word);
                    end
                end

                assign ldr_word = buffer[state.ptr];
            end
            LeaderIsWider: begin : g_narrow_to_wide
                // ptr increments on flw_hs.flag.good, with reset on flw_hs.flag.init + wraparound logic.
                assign ptr_inc   = flw_hs.flag.good;
                assign ptr_rst   = ldr_hs.flag.good;

                // valid is high when the buffer is full and ready for one wide output
                assign valid_set = flw_hs.flag.exit || (flw_hs.flag.good && (state.ptr == ptr_t'(Entries - 1)));
                assign valid_clr = ldr_hs.flag.good;

                buf_t buffer;
                always_ff @(posedge clk) begin
                    if (clk_en && flw_hs.flag.good) begin
                        buffer[state.ptr] <= flw_word;
                    end
                end

                assign ldr_word = ldr_t'(buffer);
            end
            default:
            begin : g_equal_width
                assign ptr_inc   = 1'b0;
                assign ptr_rst   = 1'b1;

                assign valid_set = flw_hs.flag.good;
                assign valid_clr = ldr_hs.flag.good;

                always_ff @(posedge clk) begin
                    if (clk_en && flw_hs.flag.good) begin
                        ldr_word <= flw_word;
                    end
                end
            end
        endcase
    endgenerate

endmodule : hs_convert_widths
