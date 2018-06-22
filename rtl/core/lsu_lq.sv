// Load Queue
// Every cycle a new load op may be allocated in the load queue when issued from the reservation station
// Every cycle a load may be deallocated from the load queue when retired from the ROB
// Every cycle a stalled load can be replayed if the cacheline it was waiting for is returned from memory
// The purpose of the load queue is to keep track of load ops until they are retired and to detect
// mis-speculated loads whenever a store op has been retired

`include "common.svh"
import procyon_types::*;

module lsu_lq (
    input  logic                 clk,
    input  logic                 n_rst,

    input  logic                 i_flush,
    output logic                 o_full,

    // Signals from LSU_ID to allocate new load op
    input  procyon_tag_t         i_alloc_tag,
    input  procyon_addr_t        i_alloc_addr,
    input  procyon_lsu_func_t    i_alloc_lsu_func,
    input  logic                 i_alloc_en,

    // Signals to LSU_EX for replaying loads
    input  logic                 i_replay_stall,
    output logic                 o_replay_en,
    output procyon_lsu_func_t    o_replay_lsu_func,
    output procyon_addr_t        o_replay_addr,
    output procyon_tag_t         o_replay_tag,

    // Signals from LSU_EX to update a load when it needs replaying
    input  logic                 i_update_lq_en,
    input  logic                 i_update_lq_retry,
    input  procyon_mhq_tag_t     i_update_lq_mhq_tag,

    // MHQ fill broadcast
    input  logic                 i_mhq_fill,
    input  procyon_mhq_tag_t     i_mhq_fill_tag,

    // SQ will send address of retiring store for mis-speculation detection
    input  procyon_addr_t        i_sq_retire_addr,
    input  procyon_lsu_func_t    i_sq_retire_lsu_func,
    input  logic                 i_sq_retire_en,

    // ROB signal that a load has been retired
    input  procyon_tag_t         i_rob_retire_tag,
    input  logic                 i_rob_retire_en,
    output logic                 o_rob_retire_misspeculated
);

    typedef logic [`LQ_DEPTH-1:0]     lq_vec_t;
    typedef logic [`LQ_TAG_WIDTH-1:0] lq_idx_t;

    // Each entry in the LQ contains the following
    // addr:              The load address
    // tag:               ROB tag used to determine age of the load op
    // lsu_func:          LSU op i.e. LB, LH, LW, LBU, LHU
    // valid:             Indicates if entry is valid
    // needs_replay:      Loads need to be replayed if they miss in the cache
    // replay_rdy:        Indicates that load is ready to be replayed
    // replay_retry:      Indicates if load was marked as needing to be replayed when the MHQ was full
    // replay_mhq_tag:    MHQ entry which corresponds to the cacheline that this load is waiting for
    // misspeculated:     Indicates if load has been mis-speculatively executed
    typedef struct packed {
        procyon_addr_t           addr;
        procyon_tag_t            tag;
        procyon_lsu_func_t       lsu_func;
        logic                    valid;
        logic                    needs_replay;
        logic                    replay_rdy;
        logic                    replay_retry;
        procyon_mhq_tag_t        replay_mhq_tag;
        logic                    misspeculated;
    } lq_slot_t;

/* verilator lint_off MULTIDRIVEN */
    lq_slot_t [`LQ_DEPTH-1:0]           lq_slots;
/* verilator lint_on  MULTIDRIVEN */
    logic                               lq_full;
<<<<<<< HEAD
    lq_vec_t                            lq_empty;
    lq_vec_t                            lq_replay;
    lq_vec_t                            lq_allocate_select;
    lq_vec_t                            lq_misspeculated_select;
    lq_vec_t                            lq_retire_select;
    lq_vec_t                            lq_replay_select;
    lq_vec_t                            lq_update_select;
    lq_vec_t                            update_select_q;
    lq_vec_t                            lq_slots_replay_rdy;
    lq_vec_t                            lq_allocate_or_retire;
    lq_idx_t                            retire_slot;
    lq_idx_t                            replay_slot;
=======
    logic     [`LQ_DEPTH-1:0]           lq_empty;
    logic     [`LQ_DEPTH-1:0]           lq_replay;
    logic     [`LQ_DEPTH-1:0]           lq_allocate_select;
    logic     [`LQ_DEPTH-1:0]           lq_misspeculated_select;
    logic     [`LQ_DEPTH-1:0]           lq_retire_select;
    logic     [`LQ_DEPTH-1:0]           lq_replay_select;
    logic     [`LQ_DEPTH-1:0]           lq_update_select;
    logic     [`LQ_DEPTH-1:0]           update_select_q;
    logic     [`LQ_DEPTH-1:0]           lq_slots_replay_rdy;
    logic     [`LQ_DEPTH-1:0]           lq_allocate_or_retire;
    logic     [`LQ_TAG_WIDTH-1:0]       retire_slot;
    logic     [`LQ_TAG_WIDTH-1:0]       replay_slot;
>>>>>>> 5fbe1b3b3a2d24576ee6182140fa478441525611
    procyon_addr_t                      sq_retire_addr_start;
    procyon_addr_t                      sq_retire_addr_end;
    logic                               replay_en;

    // Grab retired store address
    assign sq_retire_addr_start         = i_sq_retire_addr;

    // Produce a one-hot bit vector of the slot that will be used to allocate
    // the next load op. LQ is full if no bits are set in the empty vector
    assign lq_allocate_select           = {(`LQ_DEPTH){i_alloc_en}} & (lq_empty & ~(lq_empty - 1'b1));
    assign lq_full                      = lq_empty == {(`LQ_DEPTH){1'b0}};

    // Replay loads if any loads are ready to be replayed and there are no replay stalls (i.e. MHQ fill or store retire)
    assign lq_replay_select             = {(`LQ_DEPTH){~i_replay_stall}} & (lq_replay & ~(lq_replay - 1'b1));
    assign replay_en                    = lq_replay_select != {(`LQ_DEPTH){1'b0}};

    assign lq_update_select             = {(`LQ_DEPTH){i_update_lq_en}} & update_select_q;

    // Let ROB know that retired load was mis-speculated
    assign o_rob_retire_misspeculated   = lq_slots[retire_slot].misspeculated;

    // Output replaying load
    assign o_replay_en                  = replay_en;
    assign o_replay_lsu_func            = lq_slots[replay_slot].lsu_func;
    assign o_replay_addr                = lq_slots[replay_slot].addr;
    assign o_replay_tag                 = lq_slots[replay_slot].tag;

    // Ouput full signal
    assign o_full                       = lq_full;

    always_comb begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            // A slot is considered replayable if it is marked as replay ready
            lq_replay[i] = lq_slots[i].replay_rdy & lq_slots[i].valid;

            // Use the ROB tag to determine which slot will be retired by generating a retire_select one-hot bit vector
            // Only one valid slot should have the matching tag
            lq_retire_select[i] = i_rob_retire_en & (lq_slots[i].tag == i_rob_retire_tag) & lq_slots[i].valid;

            // Compare retired store address with all valid load addresses to detect mis-speculated loads
            lq_misspeculated_select[i] = i_sq_retire_en & ((lq_slots[i].addr >= sq_retire_addr_start) & (lq_slots[i].addr < sq_retire_addr_end));

            // A slot is considered empty if it is marked as not valid
            lq_empty[i] = ~lq_slots[i].valid;
        end
    end

    // Calculate retiring store end address based off of store type
    always_comb begin
        case (i_sq_retire_lsu_func)
            LSU_FUNC_SB: sq_retire_addr_end = sq_retire_addr_start + 32'b0001;
            LSU_FUNC_SH: sq_retire_addr_end = sq_retire_addr_start + 32'b0010;
            LSU_FUNC_SW: sq_retire_addr_end = sq_retire_addr_start + 32'b0100;
            default:     sq_retire_addr_end = sq_retire_addr_start + 32'b0100;
        endcase
    end

    // Convert one-hot retire_select vector into binary LQ slot #
    always_comb begin
        retire_slot = {(`LQ_TAG_WIDTH){1'b0}};

        for (int i = 0; i < `LQ_DEPTH; i++) begin
            if (lq_retire_select[i]) begin
<<<<<<< HEAD
                retire_slot = lq_idx_t'(i);
=======
                retire_slot = i[`LQ_TAG_WIDTH-1:0];
>>>>>>> 5fbe1b3b3a2d24576ee6182140fa478441525611
            end
        end
    end

    // Convert one-hot replay_select vector into binary LQ slot #
    always_comb begin
        replay_slot = {(`LQ_TAG_WIDTH){1'b0}};

        for (int i = 0; i < `LQ_DEPTH; i++) begin
            if (lq_replay_select[i]) begin
<<<<<<< HEAD
                replay_slot = lq_idx_t'(i);
=======
                replay_slot = i[`LQ_TAG_WIDTH-1:0];
>>>>>>> 5fbe1b3b3a2d24576ee6182140fa478441525611
            end
        end
    end

    // Register the update_select when a load is allocated or being replayed
    // This is used when LSU_EX needs to update LQ entry to mark a load as replayable
    always_ff @(posedge clk) begin
        if (replay_en) update_select_q <= lq_replay_select;
        else           update_select_q <= i_alloc_en ? lq_allocate_select : update_select_q;
    end

    // Set the valid when a slot is allocated, clear on flush, reset or retire
    always_ff @(posedge clk) begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            if (~n_rst) lq_slots[i].valid <= 1'b0;
            else        lq_slots[i].valid <= ~i_flush & mux4_1b(lq_slots[i].valid, 1'b1, 1'b0, 1'b1, {lq_retire_select[i], lq_allocate_select[i]});
        end
    end

    // Update slot for newly allocated load op
    always_ff @(posedge clk) begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            if (lq_allocate_select[i]) begin
                lq_slots[i].addr        <= i_alloc_addr;
                lq_slots[i].tag         <= i_alloc_tag;
                lq_slots[i].lsu_func    <= i_alloc_lsu_func;
            end
        end
    end

    // Update slot for loads that need to be replayed
    // Loads need to be replayed for two reasons:
    // 1. Cache miss where the loads will be replayed when the MHQ broadcasts
    // a fill with the matching MHQ tag that the load is waiting on
    // 2. Cache miss and the MHQ is full where the loads will be replayed on
    // any MHQ fill broadcast
    always_ff @(posedge clk) begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            lq_slots[i].needs_replay <= ~lq_allocate_select[i] & mux4_1b(lq_slots[i].needs_replay, 1'b1, 1'b0, 1'b1, {lq_replay_select[i], lq_update_select[i]});
        end
    end

    // Mark loads as replay_rdy if they need replaying and one of two conditions apply:
    // 1. If they need replaying due to a cache miss then confirm that the MHQ
    // fill tag matches the fill tag they are waiting on
    // 2. If they need replaying due to a cache miss while the MHQ is full
    // then mark replay_rdy on any fill broadcasted by the MHQ (i.e. when replay_retry is set)
    // Clear replay_rdy when the LSU signals that the replay failed, but don't clear it if the MHQ signals a fill on the same cycle
    // for the same MHQ tag that this load will be waiting on
    always_comb begin
        logic update_replay_rdy;
        logic can_replay;
        logic replay_rdy_on_fill;

        update_replay_rdy = i_mhq_fill & (i_mhq_fill_tag == i_update_lq_mhq_tag);

        for (int i = 0; i < `LQ_DEPTH; i++) begin
            can_replay                = i_mhq_fill & lq_slots[i].needs_replay;
            replay_rdy_on_fill        = lq_slots[i].replay_retry | (i_mhq_fill_tag == lq_slots[i].replay_mhq_tag);

            lq_allocate_or_retire[i]  = lq_allocate_select[i] | lq_replay_select[i];
            lq_slots_replay_rdy[i]    = ~lq_allocate_or_retire[i] & mux4_1b(lq_slots[i].replay_rdy, update_replay_rdy, replay_rdy_on_fill, update_replay_rdy, {can_replay, lq_update_select[i]});
        end
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            lq_slots[i].replay_rdy <= lq_slots_replay_rdy[i];
        end
    end

    // Update the replay_retry and replay_mhq_tag fields when a load is
    // marked as needing to be replayed
    always_ff @(posedge clk) begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            if (lq_update_select[i]) begin
                lq_slots[i].replay_retry    <= i_update_lq_retry;
                lq_slots[i].replay_mhq_tag  <= i_update_lq_mhq_tag;
            end
        end
    end

    // Update mis-speculated bit for mis-speculated loads, only if the loads
    // don't need replaying (i.e. they didn't miss in the cache)
    always_ff @(posedge clk) begin
        for (int i = 0; i < `LQ_DEPTH; i++) begin
            if (~n_rst) lq_slots[i].misspeculated <= 1'b0;
            else        lq_slots[i].misspeculated <= ~lq_allocate_or_retire[i] & (lq_misspeculated_select[i] ? ~lq_slots[i].needs_replay : lq_slots[i].misspeculated);
        end
    end

endmodule
