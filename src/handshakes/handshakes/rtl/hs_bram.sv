`include "hs_macro.sv"
module hs_bram #(
    parameter integer unsigned Size = 1
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

    typedef type (write_ptr_i) ptr_t;
    typedef type (write_data_i) data_t;

    `HS_ASSERT_W(read_ptr_hs, $clog2(Size))

    hs::flag_s write_flag;
    assign write_flag = hs::get_flags(
        .req(write_fprobe_i.req),  //
        .ack(write_fdrv_o.ack),  //
        .last(write_fprobe_i.last),  //
        .state(write_fprobe_i.state)
    );

    (* syn_ramstyle = "no_rw_check" *) data_t memory[Size];
    logic we;
    data_t read_buf;
    ptr_t read_ptr;
    assign we = clk_en && write_flag.good;
    always_ff @(posedge clk) begin
        if (we) begin
            memory[write_ptr_i] <= write_data_i;
        end
        read_buf <= memory[read_ptr];
    end

    // For maximum compatibility, we stall reads on rw hazards
    logic      rw_hazard;
    hs::fctl_s read_fctl;
    assign rw_hazard       = we && (write_ptr_i == ptr_t'(read_ptr_hs.data));
    assign read_fctl.ready = !rw_hazard;
    assign read_fctl.pause = rw_hazard;
    assign read_fctl.block = 1'b0;

    hs_io #(.T(ptr_t)) safe_ptr_hs (.*);
    hs_override_fctl hs_override_fctl (
        .flw_hs(read_ptr_hs),
        .ldr_hs(safe_ptr_hs),
        .fctl_i(read_fctl)
    );

    hs_read_mem hs_read_mem (
        .read_i_hs (safe_ptr_hs),
        .read_o_hs (read_data_hs),
        .mem_data_i(read_buf),
        .mem_ptr_o (read_ptr)
    );

    assign write_fdrv_o = hs::drive_flw(write_fprobe_i.state, hs::FctlReady);

endmodule : hs_bram
