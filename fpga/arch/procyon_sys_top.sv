/*
 * Copyright (c) 2021 Sekhar Bhattacharya
 *
 * SPDX-License-Identifier: MIT
 */

`define SRAM_ADDR_WIDTH 20
`define SRAM_DATA_WIDTH 16

`define WB_CTI_WIDTH 3
`define WB_BTE_WIDTH 2

module procyon_sys_top #(
    parameter OPTN_DATA_WIDTH         = 32,
    parameter OPTN_INSN_WIDTH         = 32,
    parameter OPTN_ADDR_WIDTH         = 32,
    parameter OPTN_RAT_DEPTH          = 32,
    parameter OPTN_NUM_IEU            = 1,
    parameter OPTN_INSN_FIFO_DEPTH    = 8,
    parameter OPTN_ROB_DEPTH          = 16,
    parameter OPTN_RS_IEU_DEPTH       = 8,
    parameter OPTN_RS_LSU_DEPTH       = 8,
    parameter OPTN_LQ_DEPTH           = 4,
    parameter OPTN_SQ_DEPTH           = 4,
    parameter OPTN_VQ_DEPTH           = 2,
    parameter OPTN_MHQ_DEPTH          = 2,
    parameter OPTN_IC_CACHE_SIZE      = 1024,
    parameter OPTN_IC_LINE_SIZE       = 32,
    parameter OPTN_IC_WAY_COUNT       = 1,
    parameter OPTN_DC_CACHE_SIZE      = 1024,
    parameter OPTN_DC_LINE_SIZE       = 32,
    parameter OPTN_DC_WAY_COUNT       = 1,
    parameter OPTN_WB_DATA_WIDTH      = 32,
    parameter OPTN_WB_ADDR_WIDTH      = 32,
    parameter OPTN_WB_SRAM_BASE_ADDR  = 0,
    parameter OPTN_HEX_FILE           = "",
    parameter OPTN_HEX_SIZE           = 0
)(
    input       logic                        CLOCK_50,
    input       logic [17:17]                SW,

    input       logic [1:0]                  KEY,

    output      logic [17:0]                 LEDR,
    output      logic [7:0]                  LEDG,

    inout  wire logic [`SRAM_DATA_WIDTH-1:0] SRAM_DQ,
    output      logic [`SRAM_ADDR_WIDTH-1:0] SRAM_ADDR,
    output      logic                        SRAM_CE_N,
    output      logic                        SRAM_WE_N,
    output      logic                        SRAM_OE_N,
    output      logic                        SRAM_LB_N,
    output      logic                        SRAM_UB_N,

    output      logic [6:0]                  HEX0,
    output      logic [6:0]                  HEX1,
    output      logic [6:0]                  HEX2,
    output      logic [6:0]                  HEX3,
    output      logic [6:0]                  HEX4,
    output      logic [6:0]                  HEX5,
    output      logic [6:0]                  HEX6,
    output      logic [6:0]                  HEX7
);

    localparam IC_LINE_WIDTH    = OPTN_IC_LINE_SIZE * 8;
    localparam RAT_IDX_WIDTH    = $clog2(OPTN_RAT_DEPTH);
    localparam WB_DATA_SIZE     = OPTN_WB_DATA_WIDTH / 8;
    localparam TEST_STATE_WIDTH = 2;
    localparam TEST_STATE_RUN   = 2'b00;
    localparam TEST_STATE_STEP  = 2'b01;
    localparam TEST_STATE_HALT  = 2'b10;
    localparam TEST_STATE_DONE  = 2'b11;

    logic [TEST_STATE_WIDTH-1:0] state;

    logic clk;
    logic n_rst;

    // FIXME: To test if simulations pass/fail
    logic [OPTN_DATA_WIDTH-1:0] sim_tp;

    // FIXME: FPGA debugging output
    logic rob_redirect;
    logic [OPTN_ADDR_WIDTH-1:0] rob_redirect_addr;
    logic rat_retire_en;
    logic [RAT_IDX_WIDTH-1:0] rat_retire_rdst;
    logic [OPTN_DATA_WIDTH-1:0] rat_retire_data;

    // FIXME: Temporary instruction cache interface
    logic ifq_full;
    logic ifq_alloc_en;
    logic [OPTN_ADDR_WIDTH-1:0] ifq_alloc_addr;
    logic ifq_fill_en;
    logic [OPTN_ADDR_WIDTH-1:0] ifq_fill_addr;
    logic [IC_LINE_WIDTH-1:0] ifq_fill_data;

    // Wishbone interface
    logic wb_rst;
    logic wb_ack;
    logic [OPTN_WB_DATA_WIDTH-1:0] wb_data_i;
    logic wb_cyc;
    logic wb_stb;
    logic wb_we;
    logic [`WB_CTI_WIDTH-1:0] wb_cti;
    logic [`WB_BTE_WIDTH-1:0] wb_bte;
    logic [WB_DATA_SIZE-1:0] wb_sel;
    logic [OPTN_WB_ADDR_WIDTH-1:0] wb_addr;
    logic [OPTN_WB_DATA_WIDTH-1:0] wb_data_o;

    logic test_finished;
    assign test_finished = (sim_tp == 'h4a33) | (sim_tp == 'hfae1);

    logic test_finished_q;
    always_ff @(posedge CLOCK_50) begin
        test_finished_q <= test_finished;
    end

    logic rob_redirect_q;
    logic [OPTN_ADDR_WIDTH-1:0] rob_redirect_addr_q;
    logic [RAT_IDX_WIDTH-1:0] rat_retire_rdst_q;
    logic [OPTN_DATA_WIDTH-1:0] rat_retire_data_q;

    always_ff @(posedge CLOCK_50) begin
        if (~n_rst) begin
            rob_redirect_q <= '0;
            rob_redirect_addr_q <= '0;
            rat_retire_rdst_q <= '0;
        end
        else if (rat_retire_en) begin
            rob_redirect_q <= rob_redirect;
            rob_redirect_addr_q <= rob_redirect_addr;
            rat_retire_rdst_q <= rat_retire_rdst;
        end
        else begin
            rob_redirect_q <= rob_redirect_q;
            rob_redirect_addr_q <= rob_redirect_addr_q;
            rat_retire_rdst_q <= rat_retire_rdst_q;
        end
    end

    always_ff @(posedge CLOCK_50) begin
        if (~n_rst) begin
            rat_retire_data_q <= '0;
        end
        else if (state == TEST_STATE_DONE) begin
            rat_retire_data_q <= sim_tp;
        end
        else if (rat_retire_en) begin
            rat_retire_data_q <= rat_retire_data;
        end
        else begin
            rat_retire_data_q <= rat_retire_data_q;
        end
    end

    logic [1:0] key;
    logic [1:0] key_pulse;
    logic rst_sync;
    logic [6:0] o_hex [0:7];

    assign n_rst = rst_sync;
    assign wb_rst = ~n_rst;

    assign key = ~KEY;
    assign LEDR[17] = rst_sync;
    assign LEDR[16] = rob_redirect_q;
    assign LEDR[15:0] = rob_redirect_addr_q[15:0];
    assign LEDG = rat_retire_rdst_q;
    assign HEX0 = o_hex[0];
    assign HEX1 = o_hex[1];
    assign HEX2 = o_hex[2];
    assign HEX3 = o_hex[3];
    assign HEX4 = o_hex[4];
    assign HEX5 = o_hex[5];
    assign HEX6 = o_hex[6];
    assign HEX7 = o_hex[7];

    always_ff @(posedge CLOCK_50) begin
        case (state)
            TEST_STATE_RUN:  clk <= ~clk;
            TEST_STATE_STEP: clk <= ~clk;
            TEST_STATE_HALT: clk <= 1'b0;
            TEST_STATE_DONE: clk <= 1'b0;
        endcase
    end

    always_ff @(negedge CLOCK_50) begin
        if (~n_rst) begin
            state <= TEST_STATE_STEP;
        end else begin
            case (state)
                TEST_STATE_RUN:  state <= test_finished_q ? TEST_STATE_DONE : (key_pulse[1] ? TEST_STATE_STEP : TEST_STATE_RUN);
                TEST_STATE_STEP: state <= rat_retire_en ? TEST_STATE_HALT : TEST_STATE_STEP;
                TEST_STATE_HALT: state <= key_pulse[1] ? TEST_STATE_RUN : (key_pulse[0] ? TEST_STATE_STEP : TEST_STATE_HALT);
                TEST_STATE_DONE: state <= key_pulse[1] ? TEST_STATE_RUN : (key_pulse[0] ? TEST_STATE_STEP : TEST_STATE_DONE);
            endcase
        end
    end

    procyon_sync #(.OPTN_DATA_WIDTH(1), .OPTN_SYNC_DEPTH(2)) rst_sync_sync (.clk(CLOCK_50), .n_rst(1'b1), .i_async_data(SW[17]), .o_sync_data(rst_sync));

    genvar inst;
    generate
        for (inst = 0; inst < 8; inst++) begin : GEN_SEG7_DECODER_INSTANCES
            procyon_seg7_decoder procyon_seg7_decoder_inst (
                .n_rst(n_rst),
                .i_hex(rat_retire_data_q[inst*4 +: 4]),
                .o_hex(o_hex[inst])
            );
        end
        for (inst = 0; inst < 2; inst++) begin : GEN_EDGE_DETECTOR_INST
            procyon_edge_detector procyon_edge_detector_inst (
                .clk(CLOCK_50),
                .n_rst(n_rst),
                .i_async(key[inst]),
                .o_pulse(key_pulse[inst])
            );
        end
    endgenerate

    ifq_stub #(
        .OPTN_ADDR_WIDTH(OPTN_ADDR_WIDTH),
        .OPTN_IC_LINE_SIZE(OPTN_IC_LINE_SIZE),
        .OPTN_HEX_FILE(OPTN_HEX_FILE),
        .OPTN_HEX_SIZE(OPTN_HEX_SIZE)
    ) ifq_stub_inst (
        .clk(clk),
        .n_rst(n_rst),
        .i_alloc_en(ifq_alloc_en),
        .i_alloc_addr(ifq_alloc_addr),
        .o_full(ifq_full),
        .o_fill_en(ifq_fill_en),
        .o_fill_addr(ifq_fill_addr),
        .o_fill_data(ifq_fill_data)
    );

    procyon #(
        .OPTN_DATA_WIDTH(OPTN_DATA_WIDTH),
        .OPTN_INSN_WIDTH(OPTN_INSN_WIDTH),
        .OPTN_ADDR_WIDTH(OPTN_ADDR_WIDTH),
        .OPTN_RAT_DEPTH(OPTN_RAT_DEPTH),
        .OPTN_NUM_IEU(OPTN_NUM_IEU),
        .OPTN_INSN_FIFO_DEPTH(OPTN_INSN_FIFO_DEPTH),
        .OPTN_ROB_DEPTH(OPTN_ROB_DEPTH),
        .OPTN_RS_IEU_DEPTH(OPTN_RS_IEU_DEPTH),
        .OPTN_RS_LSU_DEPTH(OPTN_RS_LSU_DEPTH),
        .OPTN_LQ_DEPTH(OPTN_LQ_DEPTH),
        .OPTN_SQ_DEPTH(OPTN_SQ_DEPTH),
        .OPTN_VQ_DEPTH(OPTN_VQ_DEPTH),
        .OPTN_MHQ_DEPTH(OPTN_MHQ_DEPTH),
        .OPTN_IC_CACHE_SIZE(OPTN_IC_CACHE_SIZE),
        .OPTN_IC_LINE_SIZE(OPTN_IC_LINE_SIZE),
        .OPTN_IC_WAY_COUNT(OPTN_IC_WAY_COUNT),
        .OPTN_DC_CACHE_SIZE(OPTN_DC_CACHE_SIZE),
        .OPTN_DC_LINE_SIZE(OPTN_DC_LINE_SIZE),
        .OPTN_DC_WAY_COUNT(OPTN_DC_WAY_COUNT),
        .OPTN_WB_DATA_WIDTH(OPTN_WB_DATA_WIDTH),
        .OPTN_WB_ADDR_WIDTH(OPTN_WB_ADDR_WIDTH)
    ) procyon_inst (
        .clk(clk),
        .n_rst(n_rst),
        .o_sim_tp(sim_tp),
        .o_rob_redirect(rob_redirect),
        .o_rob_redirect_addr(rob_redirect_addr),
        .o_rat_retire_en(rat_retire_en),
        .o_rat_retire_rdst(rat_retire_rdst),
        .o_rat_retire_data(rat_retire_data),
        .i_ifq_full(ifq_full),
        .i_ifq_fill_en(ifq_fill_en),
        .i_ifq_fill_addr(ifq_fill_addr),
        .i_ifq_fill_data(ifq_fill_data),
        .o_ifq_alloc_en(ifq_alloc_en),
        .o_ifq_alloc_addr(ifq_alloc_addr),
        .i_wb_clk(clk),
        .i_wb_rst(wb_rst),
        .i_wb_ack(wb_ack),
        .i_wb_data(wb_data_i),
        .o_wb_cyc(wb_cyc),
        .o_wb_stb(wb_stb),
        .o_wb_we(wb_we),
        .o_wb_cti(wb_cti),
        .o_wb_bte(wb_bte),
        .o_wb_sel(wb_sel),
        .o_wb_addr(wb_addr),
        .o_wb_data(wb_data_o)
    );

    sram_wb #(
        .OPTN_WB_DATA_WIDTH(OPTN_WB_DATA_WIDTH),
        .OPTN_WB_ADDR_WIDTH(OPTN_WB_ADDR_WIDTH),
        .OPTN_BASE_ADDR(OPTN_WB_SRAM_BASE_ADDR)
    ) sram_wb_inst (
        .i_wb_clk(clk),
        .i_wb_rst(wb_rst),
        .i_wb_cyc(wb_cyc),
        .i_wb_stb(wb_stb),
        .i_wb_we(wb_we),
        .i_wb_cti(wb_cti),
        .i_wb_bte(wb_bte),
        .i_wb_sel(wb_sel),
        .i_wb_addr(wb_addr),
        .i_wb_data(wb_data_o),
        .o_wb_data(wb_data_i),
        .o_wb_ack(wb_ack),
        .o_sram_ce_n(SRAM_CE_N),
        .o_sram_oe_n(SRAM_OE_N),
        .o_sram_lb_n(SRAM_LB_N),
        .o_sram_we_n(SRAM_WE_N),
        .o_sram_ub_n(SRAM_UB_N),
        .o_sram_addr(SRAM_ADDR),
        .io_sram_dq(SRAM_DQ)
    );

endmodule
