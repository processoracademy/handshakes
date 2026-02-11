module _hs_priority_encode #(
    parameter DataWidth   = 16,
    parameter _IndexWidth = (DataWidth == 1) ? 1 : $clog2(DataWidth)
) (
    input  [  DataWidth-1:0] data_i,
    output [_IndexWidth-1:0] index_o
);

    // Lowest Bit Isolation
    logic [DataWidth-1:0] isolated_lsb;
    assign isolated_lsb = data_i & -data_i;
    // Index Generation
    logic [  DataWidth-1:0] mask        [_IndexWidth-1:0];
    logic [_IndexWidth-1:0] scan_result;
    genvar m;
    genvar b;
    generate
        // For every Output bit
        for (m = 0; m < _IndexWidth; m = m + 1) begin : g_mask_scan
            // For every Input bit
            for (b = 0; b < DataWidth; b = b + 1) begin : g_bit_scan
                // Generate mask
                // if the m-th bit of the bit index b is set
                // then set the b-th bit in the m-th bitmask to 1, else set to 0
                assign mask[m][b] = 1'((b & (1 << m)) >> m);
            end
            // Use mask
            // ex. (Think matrix multiplication... AND is Mult, OR is Add)
            // Input:
            // 0000 1000 0000 0000
            // Mask: (AND Vertically)
            // 1010 1010 1010 1010 b0
            // 1111 0000 1111 0000 b1
            // 1100 1100 1100 1100 b2
            // 1111 1111 0000 0000 b3
            // Partial Output: (OR Horizontally)
            // 0000 1000 0000 0000
            // 0000 1000 0000 0000
            // 0000 0000 0000 0000
            // 0000 1000 0000 0000
            // Reduced Output:
            // 1011
            assign scan_result[m] = |(isolated_lsb & mask[m]);
        end
    endgenerate
    assign index_o = scan_result;

endmodule : _hs_priority_encode
