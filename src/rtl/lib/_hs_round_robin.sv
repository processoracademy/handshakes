module _hs_round_robin #(
    parameter  integer Width  = 8,
    localparam type    mask_t = logic [        Width-1:0],
    localparam type    ptr_t  = logic [$clog2(Width)-1:0]
) (
    input  logic  clk,
    input  logic  clk_en,
    input  logic  sync_rst,
    input  logic  advance_i,
    input  mask_t mask_i,
    output mask_t mask_o,
    output ptr_t  index_o
);
    typedef logic [$clog2(Width+1)-1:0] usage_t;

    mask_t  queue [Width];
    usage_t usage;

    ptr_t head, tail;
    function ptr_t next(input ptr_t ptr);
        return (ptr == ptr_t'(Width - 1)) ? '0 : (ptr + ptr_t'(1));
    endfunction : next

    logic full, empty;
    assign full  = usage >= usage_t'(Width);
    assign empty = usage == '0;

    logic  enq;
    mask_t enq_mask;
    mask_t pending;
    _hs_sr_vector #(
        .Width          (Width),
        .PrioritizeClear(1'b0)
    ) _hs_sr_vector (
        .clk       (clk),
        .clk_en    (clk_en),
        .sync_rst  (sync_rst),
        .set_i     (enq_mask),
        .set_en_i  (enq),
        .clear_i   (mask_o),
        .clear_en_i(advance_i),
        .vector_o  (pending)
    );

    always_comb begin
        mask_t filtered_input;
        filtered_input = mask_i & (~pending);
        enq_mask       = (advance_i && empty) ? (filtered_input & (~mask_o)) : filtered_input;
        enq            = (|enq_mask) && !full;
    end

    logic  deq;
    logic  update_head;
    mask_t updated_head;
    always_comb begin
        deq          = 1'b0;
        update_head  = 1'b0;
        updated_head = queue[head] & (~mask_o);
        if (advance_i && !empty) begin
            if (|updated_head) begin
                update_head = 1'b1;
            end
            else begin
                deq = 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (sync_rst) begin
            usage <= '0;
            head  <= '0;
            tail  <= '0;
        end
        else if (clk_en) begin
            usage <= usage + usage_t'(enq) - usage_t'(deq);
            if (enq) begin
                queue[tail] <= enq_mask;
                tail        <= next(tail);
            end
            if (deq) begin
                head <= next(head);
            end
            else if (update_head && ((head != tail) || !enq)) begin
                queue[head][index_o] <= 1'b0;
            end
        end
    end

    mask_t forwarded_output;
    assign forwarded_output = empty ? mask_i : queue[head];
    _hs_priority_encode #(
        .DataWidth(Width)
    ) _hs_priority_encode (
        .data_i (forwarded_output),
        .index_o(index_o)
    );
    assign mask_o = mask_t'(|forwarded_output) << index_o;

endmodule : _hs_round_robin
