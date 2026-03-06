/**
 * Interface: hs_io
 * 
 * Ports:
 *  clk      - clock
 *  clk_en   - clock enable
 *  sync_rst - sync reset
 * 
 * Parameters:
 *  W - Width of the handshake's data bus
 *  T - Type of the handshake's data bus
 * 
 * Quinn Unger 25/Nov/2025
**/
`include "hs_macro.sv"
interface hs_io #(
    parameter type T = logic
) (
    input logic clk,
    input logic clk_en,
    input logic sync_rst
);
    localparam integer unsigned W = $bits(T);
    `ifndef SV2V localparam string Typename = $typename(T); `endif
    `ifdef VERILATOR typedef T data_t;
    `else localparam type data_t = T;
    `endif

    // About: Parameter Type Support in Quartus lite/std
    // Quartus std/lite does not support parameter type. Likely until they support SV 1800-2012

    /**
     * About: Handshake State Queries
     *
     * All the flag queries are "live" and derived from handshake signals + <hs::state_e> state reg.
     *
     * The hs::READY/PROBE/MULTI/BLOCK lines refer to <hs::state_e> states.
     * This state is intended for use in case statements etc for entry, multicycle, and exit phases respectively.
     *
     * *Never* plug 4-letter query funcs into a handshake control. This will cause logic loops!
     * >   flag.init: ___-_________ high on 1st valid transfer of a handshake
     * >   flag.good: ___-__-_-____ high on confirmed transfers
     * >   flag.busy: ___---------_ high for entire active handshake
     * >   flag.live: _-----------_ high for entire handshake including the initial ldrv.req probing
     * >   flag.body: ______-_-____ high on main transfers besides init
     * >   flag.exit: ________-____ high on final pausable cycle
     * >   flag.term: ________^____ high on final pausable cycle with invalid data. flag.body/flag.good are LOW in this case.
     * >   flag.tail: _________--__ high for h/s block after tx
     * >   flag.done: ___________-_ high on h/s cooldown cycle
     * > state==
     * >   hs::READY: --__________- high when ready for a new handshake init
     * >   hs::PROBE: __--_________ high when leader is trying a handshake init. Be aware an immediate fdrv.ack skips this state.
     * >   hs::MULTI: ____-----____ high on pausable transfer cycles. Be aware that oneshot handshakes skip this state.
     * >   hs::BLOCK: _________---_ high on blockable tail cycles
     * >
     * >        ldrv.req : _---__---____ driven by leader
     * >        fdrv.ack : ___-_--_---__ driven by follower
     * >        ldrv.last: _______--____ driven by leader
     * >        data: xxAAxxBCCxxxx driven by leader
    **/

    hs::fdrv_s fdrv  /*verilator isolate_assignments*/;
    hs::ldrv_s ldrv  /*verilator isolate_assignments*/;
    T data, prev_data, data_stable;
    hs::flag_s flag, prev_flag;
    hs::state_e state, next_state;
    hs::lctl_s lctl;
    hs::fctl_s fctl;
    assign flag        = hs::get_flags(ldrv.req, fdrv.ack, ldrv.last, state);
    assign next_state  = hs::get_next_state(ldrv.req, fdrv.ack, ldrv.last, state);
    assign data_stable = flag.good ? data : prev_data;
    always_ff @(posedge clk) begin
        if (sync_rst) begin
            state     <= hs::READY;
            prev_flag <= '0;
        end
        else if (clk_en) begin
            if (flag.good) begin
                prev_data <= data;
            end
            prev_flag <= flag;
            state     <= next_state;
        end
    end

    hs::lprobe_s lprobe;
    assign lprobe.ack   = fdrv.ack;
    assign lprobe.state = state;

    hs::fprobe_s fprobe;
    assign fprobe.req   = ldrv.req;
    assign fprobe.last  = ldrv.last;
    assign fprobe.state = state;

    modport ldr(
        // Clock tree
        input clk,
        input clk_en,
        input sync_rst,

        // Core
        input flag,
        input state,
        output ldrv,
        input fdrv,
        output data,

        // Extras
        output lctl,
        input prev_flag,
        input next_state,
        input lprobe
    );

    modport flw(
        // Clock tree
        input clk,
        input clk_en,
        input sync_rst,

        // Core
        input flag,
        input state,
        input ldrv,
        output fdrv,
        input data,

        // Extras
        output fctl,
        input prev_data,
        input data_stable,
        input prev_flag,
        input next_state,
        input fprobe
    );

endinterface
