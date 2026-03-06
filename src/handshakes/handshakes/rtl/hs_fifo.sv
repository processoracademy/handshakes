`include "hs_macro.sv"
module hs_fifo #(
    parameter integer Depth        = 2,
    parameter logic   SingleFrame  = 1'b0,
    parameter logic   BufferAborts = 1'b1
) (
    hs_io.flw flw_hs,
    hs_io.ldr ldr_hs
);
    `HS_ASSERT_H(flw_hs, ldr_hs)

    wire clk = flw_hs.clk;
    wire clk_en = flw_hs.clk_en;
    wire sync_rst = flw_hs.sync_rst;

    localparam integer SafeDepth = BufferAborts ? (Depth + 1) : Depth;
    localparam integer SafePtrWidth = (SafeDepth > 1) ? $clog2(SafeDepth) : 1;

    typedef logic [flw_hs.W-1:0] data_t;
    typedef logic [SafePtrWidth-1:0] ptr_t;
    typedef logic [$clog2(SafeDepth+1)-1:0] util_t;

    localparam ptr_t AddrMax = ptr_t'(SafeDepth - 1);

    localparam integer EntryWidth = flw_hs.W + 1 + 32'(BufferAborts);
    typedef logic [EntryWidth-1:0] entry_t;

    logic   advance_ldr;
    logic   advance_flw;
    entry_t write_entry;
    entry_t read_entry;
    util_t  write_util;
    util_t  read_util;
    logic   rw_hazard;
    wire    read_empty = read_util == util_t'(0);
    wire    ldr_valid = !(rw_hazard || read_empty);
    `HS_DRIVE_LDR(ldr_hs)
    generate
        hs_io #(.T(data_t)) internal_hs (.*);
        `HS_DRIVE_FLW(internal_hs)

        if (SingleFrame) begin : g_single_frame
            _hs_sr_vector #(
                .Width          (1),
                .PrioritizeClear(1'b0)
            ) _hs_sr_vector (
                .clk       (clk),
                .clk_en    (clk_en),
                .sync_rst  (sync_rst),
                .set_i     (internal_hs.flag.init),
                .set_en_i  (1'b1),
                .clear_i   (ldr_hs.flag.done),
                .clear_en_i(1'b1),
                .vector_o  (internal_hs.fctl.block)
            );
        end
        else begin : g_multi_frame
            assign internal_hs.fctl.block = 1'b0;
        end

        if (BufferAborts) begin : g_preserve_aborts

            hs_replace_data hs_replace_data (
                .flw_hs(flw_hs),
                .ldr_hs(internal_hs),
                .data_i(data_t'(flw_hs.data))
            );

            assign advance_flw = internal_hs.flag.good || internal_hs.flag.term;
            assign advance_ldr = ldr_hs.flag.good || ldr_hs.flag.term;

            typedef struct packed {
                data_t data;
                logic  close;  // verilator lint_off SYMRSVDWORD
                logic  abort;  // verilator lint_on SYMRSVDWORD
            } entry_long_s;

            entry_long_s write;
            assign write.data             = internal_hs.data;
            assign write.close            = internal_hs.flag.exit;
            assign write.abort            = internal_hs.flag.term;
            assign write_entry            = write;

            // LT/GTE Depth is used instead of NE/EQ to account for the 1 overflow abort slot
            assign internal_hs.fctl.ready = write_util < util_t'(Depth);
            assign internal_hs.fctl.pause = write_util >= util_t'(Depth);

            entry_long_s read;
            assign read              = read_entry;
            assign ldr_hs.data       = `HS_CAST(ldr_hs, read.data);
            assign ldr_hs.lctl.start = ldr_valid;
            assign ldr_hs.lctl.pause = !ldr_valid;
            assign ldr_hs.lctl.close = read.close;
            assign ldr_hs.lctl.abort = read.abort && ldr_valid;
        end
        else begin : g_eat_aborts

            hs_io #(.T(data_t)) flw_indirect_hs (.*);
            hs_replace_data hs_replace_data (
                .flw_hs(flw_hs),
                .ldr_hs(flw_indirect_hs),
                .data_i(data_t'(flw_hs.data))
            );
            hs_absorb_aborts hs_absorb_aborts (
                .flw_hs(flw_indirect_hs),
                .ldr_hs(internal_hs)
            );

            assign advance_flw = internal_hs.flag.good;
            assign advance_ldr = ldr_hs.flag.good;

            typedef struct packed {
                data_t data;
                logic  close;
            } entry_short_s;

            entry_short_s write;
            assign write.data             = internal_hs.data;
            assign write.close            = internal_hs.flag.exit;
            assign write_entry            = write;

            assign internal_hs.fctl.ready = write_util != util_t'(Depth);
            assign internal_hs.fctl.pause = write_util == util_t'(Depth);

            entry_short_s read;
            assign read              = read_entry;
            assign ldr_hs.data       = `HS_CAST(ldr_hs, read.data);
            assign ldr_hs.lctl.start = ldr_valid;
            assign ldr_hs.lctl.pause = !ldr_valid;
            assign ldr_hs.lctl.close = read.close;
            assign ldr_hs.lctl.abort = 1'b0;
        end

    endgenerate

    ptr_t write_ptr, write_next;
    assign write_next = (write_ptr == AddrMax) ? ptr_t'(0) : (write_ptr + ptr_t'(1));

    ptr_t read_ptr_reg, read_ptr_next, read_ptr;
    assign read_ptr_next = (read_ptr_reg == AddrMax) ? ptr_t'(0) : (read_ptr_reg + ptr_t'(1));
    assign read_ptr      = advance_ldr ? read_ptr_next : read_ptr_reg;

    (* syn_ramstyle = "no_rw_check" *) entry_t fifo[SafeDepth];
    always_ff @(posedge clk) begin
        if (clk_en) begin
            if (advance_flw) begin
                fifo[write_ptr] <= write_entry;
            end
            rw_hazard <= advance_flw && (read_ptr == write_ptr);
        end
        read_entry <= fifo[read_ptr];
    end

    always_ff @(posedge clk) begin
        if (sync_rst) begin
            write_ptr    <= ptr_t'(0);
            read_ptr_reg <= ptr_t'(0);
            write_util   <= util_t'(0);
            read_util    <= util_t'(0);
        end
        else if (clk_en) begin
            if (advance_flw) begin
                write_ptr <= write_next;
            end
            read_ptr_reg <= read_ptr;
            write_util   <= write_util + util_t'(advance_flw) - util_t'(advance_ldr);
            read_util    <= (write_util == util_t'(0)) ? util_t'(0) : (write_util - util_t'(advance_ldr));
        end
    end

endmodule : hs_fifo
