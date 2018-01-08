// Instruction decode and address generation unit
// Will send signals to load or store queue to allocate op

import types::*;

module lsu_id #(
    parameter DATA_WIDTH       = 32,
    parameter ADDR_WIDTH       = 32,
    parameter TAG_WIDTH        = 6
) (
    input logic                       clk,
    input logic                       n_rst,

    // Inputs from reservation station
    input  opcode_t                   i_opcode,
    input  logic [DATA_WIDTH-1:0]     i_insn,
    input  logic [DATA_WIDTH-1:0]     i_src_a,
    input  logic [DATA_WIDTH-1:0]     i_src_b,
    input  logic [TAG_WIDTH-1:0]      i_tag,
    input                             i_valid,

    // Outputs to next pipeline stage
    output lsu_func_t                 o_lsu_func,
    output logic [ADDR_WIDTH-1:0]     o_addr,
    output logic [TAG_WIDTH-1:0]      o_tag,
    output logic                      o_valid,

    // Enqueue newly issued load/store ops in the load/store queues
    output lsu_func_t                 o_alloc_lsu_func,
    output logic [TAG_WIDTH-1:0]      o_alloc_tag,
    output logic [DATA_WIDTH-1:0]     o_alloc_data,
    output logic [ADDR_WIDTH-1:0]     o_alloc_addr,
    output logic                      o_alloc_sq_en,
    output logic                      o_alloc_lq_en
);

    lsu_func_t              lsu_func;

    logic [DATA_WIDTH-1:0]  imm_i;
    logic [DATA_WIDTH-1:0]  imm_s;

    logic [ADDR_WIDTH-1:0]  addr;

    // 1 if store, 0 if load
    logic                   load_or_store;

    // Generate immediates
    assign imm_i            = {{(DATA_WIDTH-11){i_insn[31]}}, i_insn[30:25], i_insn[24:20]};
    assign imm_s            = {{(DATA_WIDTH-11){i_insn[31]}}, i_insn[30:25], i_insn[11:7]};

    // Determine if op is load or store
    assign load_or_store    = i_opcode == OPCODE_STORE;

    // Calculate address
    assign addr             = i_src_a + (load_or_store ? imm_s : imm_i);

    // Allocate op in load queue or store queue
    assign o_alloc_lsu_func = lsu_func;
    assign o_alloc_tag      = i_tag;
    assign o_alloc_data     = i_src_b;
    assign o_alloc_addr     = addr;
    assign o_alloc_sq_en    = load_or_store;
    assign o_alloc_lq_en    = ~load_or_store;

    // Assign outputs to next stage in the pipeline
    assign o_lsu_func       = lsu_func;
    assign o_addr           = addr;
    assign o_tag            = i_tag;
    assign o_valid          = i_valid;

    // Decode load/store type based on funct3 field
    always_comb begin
        case (i_opcode) begin
            OPCODE_STORE: begin
                case (i_insn[14:12]) begin
                    3'b000:  lsu_func = LSU_FUNC_SB;
                    3'b001:  lsu_func = LSU_FUNC_SH;
                    3'b010:  lsu_func = LSU_FUNC_SW;
                    default: lsu_func = LSU_FUNC_SW;
                endcase
            end
            OPCODE_LOAD: begin
                case (i_insn[14:12]) begin
                    3'b000:  lsu_func = LSU_FUNC_LB;
                    3'b001:  lsu_func = LSU_FUNC_LH;
                    3'b010:  lsu_func = LSU_FUNC_LW;
                    3'b100:  lsu_func = LSU_FUNC_LB;
                    3'b101:  lsu_func = LSU_FUNC_LH;
                    default: lsu_func = LSU_FUNC_LW;
                endcase
            end
            default: lsu_func = LSU_FUNC_LB;
        endcase
    end

endmodule
