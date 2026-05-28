`include "hs_macro.sv"
module hs_memory #(
    parameter integer unsigned Size           = 1,
    parameter logic            SelfClear      = 1'b0,
    parameter logic            SimultaneousRW = 1'b1
) (
           hs_io.flw                         read_ptr_hs,
           hs_io.ldr                         read_data_hs,
    input  hs::fprobe_s                      write_fprobe_i,
    output hs::fdrv_s                        write_fdrv_o,
    input  logic        [read_data_hs.W-1:0] write_data_i,
    input  logic        [ read_ptr_hs.W-1:0] write_ptr_i
);
    wire clk = read_ptr_hs.clk;
    wire clk_en = read_ptr_hs.clk_en;
    wire sync_rst = read_ptr_hs.sync_rst;

    initial begin
        assert (read_ptr_hs.W >= $clog2(Size))
        else $fatal(1, "Pointer width %0d must be able to address maximum size %0d", read_ptr_hs.W, Size);
    end

    typedef type (write_ptr_i) ptr_t;
    typedef type (write_data_i) data_t;
    typedef struct packed {
        ptr_t  ptr;
        data_t data;
    } write_s;

    hs_io #(.T(ptr_t)) deref_read_hs (.*);
    hs_replace_data hs_replace_data (
        .flw_hs(read_ptr_hs),
        .ldr_hs(deref_read_hs),
        .data_i(read_ptr_hs.data)
    );
    hs_io #(.T(write_s)) deref_write_hs (.*);
    assign deref_write_hs.ldrv.req  = write_fprobe_i.req;
    assign deref_write_hs.ldrv.last = write_fprobe_i.last;
    assign write_fdrv_o             = deref_write_hs.fdrv;
    assign deref_write_hs.data.ptr  = write_ptr_i;
    assign deref_write_hs.data.data = write_data_i;

    hs_io #(.T(ptr_t)) rd_1_hs (.*);
    hs_io #(.T(write_s)) wr_1_hs (.*);
    generate
        hs_io #(.T(ptr_t)) rd_0_hs (.*);
        hs_io #(.T(write_s)) wr_0_hs (.*);
        if (SimultaneousRW) begin : g_simultaneous_rw
            hs_reflect hs_reflect_write (
                .flw_hs(deref_write_hs),
                .ldr_hs(wr_0_hs)
            );
            hs_reflect hs_reflect_read (
                .flw_hs(deref_read_hs),
                .ldr_hs(rd_0_hs)
            );
        end
        else begin : g_restricted_rw
            hs_alternate hs_alternate (
                .flw_a_hs(deref_read_hs),
                .flw_b_hs(deref_write_hs),
                .ldr_a_hs(rd_0_hs),
                .ldr_b_hs(wr_0_hs)
            );
        end
        if (SelfClear) begin : g_clear_on_reset
            hs_io #(.T(ptr_t)) clear_hs (.*);
            logic cleared, trigger;
            always_ff @(posedge clk) begin
                if (sync_rst) begin
                    cleared <= 1'b0;
                    trigger <= 1'b0;
                end
                else if (clk_en) begin
                    trigger <= 1'b1;
                    if (clear_hs.flag.done) begin
                        cleared <= 1'b1;
                    end
                end
            end
            hs_io #(.T(logic)) trigger_hs (.*);
            hs_capture_on_rising_edge hs_capture_on_rising_edge (
                .ldr_hs (trigger_hs),
                .sense_i(trigger),
                .data_i (1'b0)
            );
            hs_iterate hs_iterate (
                .iterator_hs(clear_hs),
                .fprobe_i   (trigger_hs.fprobe),
                .fdrv_o     (trigger_hs.fdrv),
                .from_i     (ptr_t'(0)),
                .to_i       (ptr_t'(Size - 1))
            );
            hs_io #(.T(write_s)) wr_mux_hs[2] (.*);
            write_s clear_data;
            assign clear_data.ptr  = clear_hs.data;
            assign clear_data.data = '0;
            hs_replace_data hs_replace_data_clear (
                .flw_hs(clear_hs),
                .ldr_hs(wr_mux_hs[0]),
                .data_i(clear_data)
            );
            hs::fctl_s fctl;
            assign fctl.ready = cleared;
            assign fctl.pause = 1'b0;
            assign fctl.block = 1'b0;
            hs_override_fctl hs_override_fctl_wr (
                .flw_hs(wr_0_hs),
                .ldr_hs(wr_mux_hs[1]),
                .fctl_i(fctl)
            );
            hs_arbitrate_leaders #(
                .Leaders(2)
            ) hs_arbitrate_leaders (
                .flw_hs(wr_mux_hs),
                .ldr_hs(wr_1_hs),
                .addr  (),
                .mask  ()
            );
            hs_override_fctl hs_override_fctl_rd (
                .flw_hs(rd_0_hs),
                .ldr_hs(rd_1_hs),
                .fctl_i(fctl)
            );
        end
        else begin : g_no_self_clear
            hs_reflect hs_reflect_write (
                .flw_hs(wr_0_hs),
                .ldr_hs(wr_1_hs)
            );
            hs_reflect hs_reflect_read (
                .flw_hs(rd_0_hs),
                .ldr_hs(rd_1_hs)
            );
        end
    endgenerate

    hs_bram #(
        .Size(Size)
    ) hs_bram (
        .read_ptr_hs   (rd_1_hs),
        .read_data_hs  (read_data_hs),
        .write_fprobe_i(wr_1_hs.fprobe),
        .write_fdrv_o  (wr_1_hs.fdrv),
        .write_data_i  (wr_1_hs.data.data),
        .write_ptr_i   (wr_1_hs.data.ptr)
    );
endmodule : hs_memory
