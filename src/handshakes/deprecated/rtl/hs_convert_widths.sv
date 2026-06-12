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
 * Quinn Unger 25/Oct/2023
**/

`include "hs_macro.sv"
module hs_convert_widths #(
    parameter logic BigEndian = 1'b0
) (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    initial $warning("hs_convert_widths is deprecated!");

    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

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

    typedef logic [$clog2(Entries+1)-1:0] entries_t;

`ifdef SIM_DEBUG
    generate
        if (BufOversize > 0) begin : g_enforce_even_fit_error
            $fatal(0, "flw_hs width (%0d) and ldr_hs width (%0d) do not divide evenly!", flw_hs.W, ldr_hs.W);
        end
    endgenerate
`endif

    generate
        case (WidthTest)
            FollowerIsWider: begin : g_wide_to_narrow
                hs_io #(.T(logic [ldr_hs.W-1:0])) internal_hs (.*);
                hs_serialize #(
                    .WideW    (WideWidth),
                    .BigEndian(BigEndian)
                ) hs_serialize (
                    .data_i   (flw_hs.data),
                    .length_i (entries_t'(Entries)),
                    .fprobe_i (flw_hs.fprobe),
                    .fdrv_o   (flw_hs.fdrv),
                    .narrow_hs(internal_hs)
                );
                hs_replace_data hs_replace_data (
                    .flw_hs(internal_hs),
                    .ldr_hs(ldr_hs),
                    .data_i(internal_hs.data)
                );
            end
            LeaderIsWider: begin : g_narrow_to_wide
                logic [ldr_hs.W-1:0] ldr_data;
                hs_deserialize #(
                    .WideW    (WideWidth),
                    .BigEndian(BigEndian)
                ) hs_deserialize (
                    .narrow_hs(flw_hs),
                    .data_o   (ldr_data),
                    .length_o (),
                    .lprobe_i (ldr_hs.lprobe),
                    .ldrv_o   (ldr_hs.ldrv)
                );
                assign ldr_hs.data = `HS_CAST(ldr_hs, ldr_data);
            end
            default:
            begin : g_equal_width
                hs_register hs_register (
                    .flw_hs(flw_hs),
                    .ldr_hs(ldr_hs)
                );
            end
        endcase
    endgenerate

endmodule : hs_convert_widths
