/**
 * Package: hs
 * 
 * Contains main structure definitions for handshakes.
 * 
 * Quinn Unger 27/July/2023
**/
package hs;

    // Enum: state_e
    // Handshake main state.
    // The lsb and msb align with ldr and flw peak activity respectively.
    //
    // READY - Idle state
    // PROBE - Leader probing for follower acknowledgement
    // MULTI - Main pausable state
    // BLOCK - Blockable tail state
    typedef enum logic [1:0] {
        READY = 2'b00,
        PROBE = 2'b01,
        MULTI = 2'b11,
        BLOCK = 2'b10
    } state_e;

    typedef enum {
        UndefinedSync,
        NoFrameSync,
        FrameSync,
        Truncate
    } sync_policy_e;

    // function: ldr_active
    // Returns true when the leader state is PROBE or MULTI (Actively trying to send data)
    function logic ldr_active(input state_e state);
        return state[0];
    endfunction : ldr_active

    // Function: flw_active
    // Returns true when the follower state is MULTI or BLOCK (Actively responding to the leader or deciding when to release the hs frame)
    function logic flw_active(input state_e state);
        return state[1];
    endfunction : flw_active

    // Struct: lctl_s
    // Contains all the control signals for driving <hs_driver_ldr>
    //
    // start - if high while handshake isn't active, commits the driver to starting a new handshake.
    // pause - pauses the active handshake if in the main data transfer phase.
    // close - signals that the current data is the final word of the transfer.
    // abort - closes the handshake without signalling that the data is valid.
    typedef struct packed {
        logic unsigned start;
        logic unsigned pause;
        logic unsigned close;  // verilator lint_off SYMRSVDWORD
        logic unsigned abort;  // verilator lint_on SYMRSVDWORD
    } lctl_s;

    // Struct: fctl_s
    // Contains all the control signals for driving <hs_driver_flw>
    //
    // ready - set high when ready to accept a new handshake session.
    // pause - set high to pause an active handshake session during the data transfer phase.
    // block - set high to block a handshake session from closing.
    typedef struct packed {
        logic unsigned ready;
        logic unsigned pause;
        logic unsigned block;
    } fctl_s;

    // Struct: flag_s
    // Flag struct for <hs_io> interfaces. See <hs_io::Handshake State Queries>
    //
    // init - high on 1st valid transfer of a handshake
    // good - high on confirmed transfers
    // busy - high for entire active handshake
    // live - high for entire handshake including the initial req probing
    // body - high on main transfers besides init
    // exit - high on final pausable cycle
    // term - high on final pausable cycle with invalid data. flag.body/flag.good are LOW in this case.
    // tail - high for h/s block after tx
    // done - high on h/s cooldown cycle
    typedef struct packed {
        logic init;
        logic good;
        logic busy;
        logic live;
        logic body;
        logic exit;
        logic term;
        logic tail;
        logic done;
    } flag_s;

    typedef struct packed {logic ack;} fdrv_s;

    typedef struct packed {
        logic req;
        logic last;
    } ldrv_s;

    typedef struct packed {
        logic   ack;
        state_e state;
    } lprobe_s;

    typedef struct packed {
        logic   req;
        logic   last;
        state_e state;
    } fprobe_s;

    function flag_s get_flags(input logic req, input logic ack, input logic last, input state_e state);
        get_flags.init = req && ack && !hs::flw_active(state);
        get_flags.good = req && ack;
        get_flags.busy = req && ack || hs::flw_active(state);
        get_flags.live = req || (state != hs::READY);
        get_flags.body = req && ack && (state == hs::MULTI);
        get_flags.exit = (last && req && ack) || (last && (state == hs::MULTI) && !req);  // Second OR term is flag.term
        get_flags.term = last && (state == hs::MULTI) && !req;
        get_flags.tail = (state == hs::BLOCK) && ack;
        get_flags.done = (state == hs::BLOCK) && !ack;
    endfunction : get_flags

    function state_e get_next_state(input logic req, input logic ack, input logic last, input state_e state);
        unique casez ({
            req, ack, last, state
        })
            {
                3'b0??, 2'b0?
            },  // normal idle or ldr abort on hs::PROBE
            {
                3'b?0?, hs::BLOCK
            } :  // flw drops ack to leave hs::BLOCK state
            get_next_state = hs::READY;

            {
                3'b10?, 2'b0?
            } :  // ldr attempting to establish handshake
            get_next_state = hs::PROBE;

            {
                3'b110, 2'b0?
            },  // normal entry into mutli-xfer
            {
                3'b??0, hs::MULTI
            },  // continuation of multi-xfer
            {
                3'b101, hs::MULTI
            } :  // flw paused on final mutli-xfer
            get_next_state = hs::MULTI;

            {
                3'b111, 2'b0?
            },  // Normal one-shot exit
            {
                3'b111, hs::MULTI
            },  // Normal multi-xfer exit
            {
                3'b0?1, hs::MULTI
            },  // ldr abort in multi-xfer
            {
                3'b?1?, hs::BLOCK
            } :  // flw raises ack to remain in hs::BLOCK
            get_next_state = hs::BLOCK;
        endcase
    endfunction : get_next_state

    function logic unsigned derive_ack(input state_e state, input fctl_s fctl);
        unique case (state)
            hs::READY: return fctl.ready;
            hs::PROBE: return fctl.ready;
            hs::MULTI: return !fctl.pause;
            hs::BLOCK: return fctl.block;
        endcase
    endfunction : derive_ack

    function logic unsigned derive_req(input state_e state, input lctl_s lctl);
        unique case (state)
            hs::READY: return lctl.start && !lctl.abort;
            hs::PROBE: return !lctl.abort;
            hs::MULTI: return !(lctl.pause || lctl.abort);
            hs::BLOCK: return 1'b0;
        endcase
    endfunction : derive_req

    function logic unsigned derive_last(input state_e state, input lctl_s lctl);
        // note: a single pulse of last is used as a graceful reset, triggering flag.exit but not flag.good
        unique case (state)
            hs::READY: return lctl.close && lctl.start && !lctl.abort;
            hs::PROBE: return lctl.close && !lctl.abort;
            hs::MULTI: return (lctl.close && !lctl.pause) || lctl.abort;
            hs::BLOCK: return 1'b0;
        endcase
    endfunction : derive_last

    function fdrv_s drive_flw(input state_e state, input fctl_s fctl);
        drive_flw.ack = derive_ack(state, fctl);
    endfunction : drive_flw

    function ldrv_s drive_ldr(input state_e state, input lctl_s lctl);
        drive_ldr.req  = derive_req(state, lctl);
        drive_ldr.last = derive_last(state, lctl);
    endfunction : drive_ldr

    function fctl_s fctl_not_ready();
        fctl_s fctl;
        fctl.ready = 1'b0;
        fctl.pause = 1'b0;
        fctl.block = 1'b0;
        return fctl;
    endfunction : fctl_not_ready
    localparam fctl_s FctlNotReady = fctl_not_ready();

    function fctl_s fctl_ready();
        fctl_s fctl;
        fctl.ready = 1'b1;
        fctl.pause = 1'b0;
        fctl.block = 1'b0;
        return fctl;
    endfunction : fctl_ready
    localparam fctl_s FctlReady = fctl_ready();

    function fctl_s fctl_ready_blocking();
        fctl_s fctl;
        fctl.ready = 1'b1;
        fctl.pause = 1'b0;
        fctl.block = 1'b1;
        return fctl;
    endfunction : fctl_ready_blocking
    localparam fctl_s FctlReadyBlocking = fctl_ready_blocking();

    function fctl_s fctl_pause();
        fctl_s fctl;
        fctl.ready = 1'b0;
        fctl.pause = 1'b1;
        fctl.block = 1'b0;
        return fctl;
    endfunction : fctl_pause
    localparam fctl_s FctlPause = fctl_pause();

    function fctl_s fctl_continue();
        fctl_s fctl;
        fctl.ready = 1'b0;
        fctl.pause = 1'b0;
        fctl.block = 1'b0;
        return fctl;
    endfunction : fctl_continue
    localparam fctl_s FctlContinue = fctl_continue();

    function fctl_s fctl_continue_blocking();
        fctl_s fctl;
        fctl.ready = 1'b0;
        fctl.pause = 1'b0;
        fctl.block = 1'b1;
        return fctl;
    endfunction : fctl_continue_blocking
    localparam fctl_s FctlContinueBlocking = fctl_continue_blocking();

    function fctl_s fctl_pause_blocking();
        fctl_s fctl;
        fctl.ready = 1'b0;
        fctl.pause = 1'b1;
        fctl.block = 1'b1;
        return fctl;
    endfunction : fctl_pause_blocking
    localparam fctl_s FctlPauseBlocking = fctl_pause_blocking();

    function fctl_s fctl_block();
        fctl_s fctl;
        fctl.ready = 1'b0;
        fctl.pause = 1'b0;
        fctl.block = 1'b1;
        return fctl;
    endfunction : fctl_block
    localparam fctl_s FctlBlock = fctl_block();

    function lctl_s lctl_idle();
        lctl_s lctl;
        lctl.start = 1'b0;
        lctl.pause = 1'b0;
        lctl.close = 1'b0;
        lctl.abort = 1'b0;
        return lctl;
    endfunction : lctl_idle
    localparam lctl_s LctlIdle = lctl_idle();

    function lctl_s lctl_start();
        lctl_s lctl;
        lctl.start = 1'b1;
        lctl.pause = 1'b0;
        lctl.close = 1'b0;
        lctl.abort = 1'b0;
        return lctl;
    endfunction : lctl_start
    localparam lctl_s LctlStart = lctl_start();

    function lctl_s lctl_pause();
        lctl_s lctl;
        lctl.start = 1'b0;
        lctl.pause = 1'b1;
        lctl.close = 1'b0;
        lctl.abort = 1'b0;
        return lctl;
    endfunction : lctl_pause
    localparam lctl_s LctlPause = lctl_pause();

    function lctl_s lctl_resume();
        lctl_s lctl;
        lctl.start = 1'b0;
        lctl.pause = 1'b0;
        lctl.close = 1'b0;
        lctl.abort = 1'b0;
        return lctl;
    endfunction : lctl_resume
    localparam lctl_s LctlResume = lctl_resume();

    function lctl_s lctl_last();
        lctl_s lctl;
        lctl.start = 1'b0;
        lctl.pause = 1'b0;
        lctl.close = 1'b1;
        lctl.abort = 1'b0;
        return lctl;
    endfunction : lctl_last
    localparam lctl_s LctlLast = lctl_last();

    function lctl_s lctl_single();
        lctl_s lctl;
        lctl.start = 1'b1;
        lctl.pause = 1'b0;
        lctl.close = 1'b1;
        lctl.abort = 1'b0;
        return lctl;
    endfunction : lctl_single
    localparam lctl_s LctlSingle = lctl_single();

    function lctl_s lctl_abort();
        lctl_s lctl;
        lctl.start = 1'b0;
        lctl.pause = 1'b1;
        lctl.close = 1'b0;
        lctl.abort = 1'b1;
        return lctl;
    endfunction : lctl_abort
    localparam lctl_s LctlAbort = lctl_abort();

endpackage : hs
