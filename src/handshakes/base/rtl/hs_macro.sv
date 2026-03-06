`ifndef HS_MACRO_
`define HS_MACRO_

`define HS_CAST(from_hs, to_data) \
`ifdef SV2V (from_hs.W)'(to_data) \
`else type (from_hs.data)'(to_data) \
`endif

// Macro: HS_ASSERT_W
// Assert that the width of a handshake is the same as provided width.
// On failure, a compilation-time fatal error is emitted
//
// Parameters:
//  hs     - <hs_io> interface to check the data width of
//  data_w - width value to check against
`define HS_ASSERT_W(hs, data_w) \
initial assert (hs.W == data_w) else $warning("%s width (%0d) must equal %s (%0d)",`"hs`",hs.W,`"data_w`",data_w);

// Macro: HS_ASSERT_T
// Assert that the width of a handshake is the same as the width of provided type.
// On failure, a compilation-time fatal error is emitted
//
// Parameters:
//  hs     - <hs_io> interface to check
//  type_t - type to check against
`define HS_ASSERT_T(hs,
                    type_t) \
initial assert \
`ifdef VERILATOR (type(hs.data) == type(type_t)) \
`else (hs.W == $bits(type_t)) \
`endif \
else $warning("handshake %s.data's %0d-bit type (%s) must equal %0d-bit type %s (%s)",`"hs`",hs.W,hs.Typename,$bits(type_t),`"type_t`",$typename(type_t));

// Macro: HS_ASSERT_H
// Assert that the width of one handshake's data is equal to another's.
// On failure, a compilation-time fatal error is emitted
//
// Parameters:
//  hs_0 - first <hs_io> interface to check
//  hs_1 - second <hs_io> interface to check
`define HS_ASSERT_H(hs_0,
                    hs_1) \
initial assert \
`ifdef VERILATOR (type(hs_0.data) == type(hs_1.data)) \
`else (hs_0.W == hs_1.W) \
`endif \
else $warning("handshake %s.data's %0d-bit type (%s) must equal handshake %s.data's %0d-bit type %s",`"hs_0`",hs_0.W,hs_0.Typename,`"hs_1`",hs_1.W,hs_1.Typename);

`define HS_EXPECT_MIN(hs, min) `ifdef SIM_DEBUG \
generate \
    integer unsigned __hs_expect_min_``hs; \
    initial __hs_expect_min_``hs = '0; \
    always_ff @(posedge hs.clk) begin \
        if(hs.sync_rst) begin \
            __hs_expect_min_``hs <= '0; \
        end \
        else if(hs.clk_en) begin \
            if(hs.flag.exit) begin \
                case(hs.flag.term) \
                    1'b1: assert (__hs_expect_min_``hs >= min) \
                        else $warning("%s data ran for too few cycles (%0d). There should be a minimum of %0d.", `"hs`", __hs_expect_min_``hs, min); \
                    1'b0: assert (__hs_expect_min_``hs >= (min - 1)) \
                        else $warning("%s data ran for too few cycles (%0d). There should be a minimum of %0d.", `"hs`", (__hs_expect_min_``hs + 1), min); \
                endcase \
                __hs_expect_min_``hs <= '0; \
            end \
            else if(hs.flag.good && (__hs_expect_min_``hs < 32'hFFFF_FFFF)) begin \
                __hs_expect_min_``hs <= __hs_expect_min_``hs + 1; \
            end \
        end \
    end \
endgenerate \
`endif

`define HS_EXPECT_MAX(hs, max) `ifdef SIM_DEBUG \
generate \
    integer unsigned __hs_expect_max_``hs; \
    initial __hs_expect_max_``hs = '0; \
    always_ff @(posedge hs.clk) begin \
        if(hs.sync_rst) begin \
            __hs_expect_max_``hs <= '0; \
        end \
        else if(hs.clk_en) begin \
            if(hs.flag.exit) begin \
                __hs_expect_max_``hs <= '0; \
            end \
            else if(hs.flag.good && (__hs_expect_max_``hs < 32'hFFFF_FFFF)) begin \
                assert ((__hs_expect_max_``hs + 1) <= max) else $warning("%s data ran for too many cycles (%0d). There should only be a maximum of %0d.", `"hs`", (__hs_expect_max_``hs + 1), max); \
                __hs_expect_max_``hs <= __hs_expect_max_``hs + 1; \
            end \
        end \
    end \
endgenerate \
`endif

`define HS_EXPECT_RANGE(hs, min, max) \
`HS_EXPECT_MIN(hs, min) `HS_EXPECT_MAX(hs, max)

`define HS_EXPECT_EXACT(hs, amount) \
`HS_EXPECT_MIN(hs, amount) `HS_EXPECT_MAX(hs, amount)

`define HS_EXPECT_ONESHOT(hs) \
`HS_EXPECT_MAX(hs, 1)

`define HS_EXPECT_ONESHOT_T(hs, type_t) \
`HS_ASSERT_T(hs, type_t) `HS_EXPECT_MAX(hs, 1)

`define HS_EXPECT_MIN_T(hs, min, type_t) \
`HS_ASSERT_T(hs, type_t) `HS_EXPECT_MIN(hs, min)

`define HS_EXPECT_MAX_T(hs, max, type_t) \
`HS_ASSERT_T(hs, type_t) `HS_EXPECT_MAX(hs, max)

`define HS_EXPECT_RANGE_T(hs, min, max, type_t) \
`HS_ASSERT_T(hs, type_t) `HS_EXPECT_MIN(hs, min) `HS_EXPECT_MAX(hs, max)

`define HS_EXPECT_EXACT_T(hs, amount, type_t) \
`HS_ASSERT_T(hs, type_t) `HS_EXPECT_MIN(hs, amount) `HS_EXPECT_MAX(hs, amount)

// Macro: HS_DRIVE_LDR
// Connect the leader handshake to its <hs::lctl_s> lctl control struct.
//
// Parameters:
//  hs - the <hs_io> handshake interface to drive
`define HS_DRIVE_LDR(ldr_hs, lctl) \
assign ldr_hs.ldrv = hs::drive_ldr(ldr_hs.state, lctl);

// Macro: HS_DRIVE_FLW
// Connect the follower handshake to its <hs::fctl_s> fctl control struct.
//
// Parameters:
//  hs - the <hs_io> handshake interface to drive
`define HS_DRIVE_FLW(flw_hs, fctl) \
assign flw_hs.fdrv = hs::drive_flw(flw_hs.state, fctl);

`endif
