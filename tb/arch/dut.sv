/*
 * Copyright (c) 2021 Sekhar Bhattacharya
 *
 * SPDX-License-Identifier: MIT
 */

`define SRAM_ADDR_WIDTH 20
`define SRAM_DATA_WIDTH 16

`define WB_CTI_WIDTH    3
`define WB_BTE_WIDTH    2

module dut #(
    parameter OPTN_DATA_WIDTH         = 32,
    parameter OPTN_INSN_WIDTH         = 32,
    parameter OPTN_ADDR_WIDTH         = 32,
    parameter OPTN_RAT_DEPTH          = 32,
    parameter OPTN_NUM_IEU            = 1,
    parameter OPTN_INSN_FIFO_DEPTH    = 32,
    parameter OPTN_ROB_DEPTH          = 128,
    parameter OPTN_RS_IEU_DEPTH       = 32,
    parameter OPTN_RS_LSU_DEPTH       = 32,
    parameter OPTN_LQ_DEPTH           = 16,
    parameter OPTN_SQ_DEPTH           = 16,
    parameter OPTN_VQ_DEPTH           = 16,
    parameter OPTN_MHQ_DEPTH          = 16,
    parameter OPTN_IC_CACHE_SIZE      = 1024,
    parameter OPTN_IC_LINE_SIZE       = 32,
    parameter OPTN_IC_WAY_COUNT       = 1,
    parameter OPTN_DC_CACHE_SIZE      = 1024,
    parameter OPTN_DC_LINE_SIZE       = 32,
    parameter OPTN_DC_WAY_COUNT       = 1,
    parameter OPTN_WB_DATA_WIDTH      = 32,
    parameter OPTN_WB_ADDR_WIDTH      = 32,
    parameter OPTN_WB_SRAM_BASE_ADDR  = 0
)(
    input  logic                            clk,
    input  logic                            n_rst,

    // SRAM interface
    output logic [`SRAM_ADDR_WIDTH-1:0]     o_sram_addr,
    input  logic [`SRAM_DATA_WIDTH-1:0]     i_sram_dq,
    output logic [`SRAM_DATA_WIDTH-1:0]     o_sram_dq,
    output logic                            o_sram_ce_n,
    output logic                            o_sram_we_n,
    output logic                            o_sram_oe_n,
    output logic                            o_sram_ub_n,
    output logic                            o_sram_lb_n,

    // FIXME: To test if simulations pass/fail
    output logic [OPTN_DATA_WIDTH-1:0]      o_sim_tp,
    output logic                            o_sim_retire,

    // FIXME: Temporary instruction fetch queue interface
    input  logic                            i_ifq_fill_en,
    input  logic [OPTN_ADDR_WIDTH-1:0]      i_ifq_fill_addr,
    input  logic [OPTN_IC_LINE_SIZE*8-1:0]  i_ifq_fill_data,
    output logic                            o_ifq_alloc_en,
    output logic [OPTN_ADDR_WIDTH-1:0]      o_ifq_alloc_addr
);

    timeunit 1ns;
    timeprecision 1ns;

    localparam RAT_IDX_WIDTH    = $clog2(OPTN_RAT_DEPTH);
    localparam WB_DATA_SIZE     = OPTN_WB_DATA_WIDTH / 8;

    logic wb_clk;
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

    logic sram_we_n;
/* verilator lint_off UNOPTFLAT */
    logic [`SRAM_DATA_WIDTH-1:0] sram_dq;
/* verilator lint_on  UNOPTFLAT */

/* verilator lint_off UNUSED */
    // FIXME: FPGA debugging output
    logic rob_redirect;
    logic [OPTN_ADDR_WIDTH-1:0] rob_redirect_addr;
    logic rat_retire_en;
    logic [RAT_IDX_WIDTH-1:0] rat_retire_rdst;
    logic [OPTN_DATA_WIDTH-1:0] rat_retire_data;
/* verilator lint_on  UNUSED */

    assign o_sim_retire = rat_retire_en;

    assign wb_clk = clk;
    assign wb_rst = ~n_rst;

    assign sram_dq = sram_we_n ? i_sram_dq : 'z;
    assign o_sram_we_n = sram_we_n;
    assign o_sram_dq = sram_dq;

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
        .o_sim_tp(o_sim_tp),
        .o_rob_redirect(rob_redirect),
        .o_rob_redirect_addr(rob_redirect_addr),
        .o_rat_retire_en(rat_retire_en),
        .o_rat_retire_rdst(rat_retire_rdst),
        .o_rat_retire_data(rat_retire_data),
        .i_ifq_full('0),
        .i_ifq_fill_en(i_ifq_fill_en),
        .i_ifq_fill_addr(i_ifq_fill_addr),
        .i_ifq_fill_data(i_ifq_fill_data),
        .o_ifq_alloc_en(o_ifq_alloc_en),
        .o_ifq_alloc_addr(o_ifq_alloc_addr),
        .i_wb_clk(wb_clk),
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
        .i_wb_clk(wb_clk),
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
        .o_sram_ce_n(o_sram_ce_n),
        .o_sram_oe_n(o_sram_oe_n),
        .o_sram_we_n(sram_we_n),
        .o_sram_lb_n(o_sram_lb_n),
        .o_sram_ub_n(o_sram_ub_n),
        .o_sram_addr(o_sram_addr),
        .io_sram_dq(sram_dq)
    );

endmodule
