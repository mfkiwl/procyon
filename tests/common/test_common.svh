`define SRAM_ADDR_WIDTH 20
`define SRAM_DATA_WIDTH 16

`define WB_DATA_WIDTH 16
`define WB_ADDR_WIDTH 32
`define WB_WORD_SIZE  (`WB_DATA_WIDTH/8)

`define WB_SRAM_BASE_ADDR 0
`define WB_SRAM_FIFO_DEPTH 8

`define DATA_WIDTH 32

`define CACHE_SIZE            (64)
`define CACHE_LINE_SIZE       (32)

`define CACHE_WORD_SIZE       (`DATA_WIDTH/8)
`define CACHE_INDEX_COUNT     (`CACHE_SIZE/`CACHE_LINE_SIZE)
`define CACHE_OFFSET_WIDTH    ($clog2(`CACHE_LINE_SIZE))
`define CACHE_INDEX_WIDTH     ($clog2(`CACHE_INDEX_COUNT))
`define CACHE_TAG_WIDTH       (`ADDR_WIDTH-`CACHE_INDEX_WIDTH-`CACHE_OFFSET_WIDTH)
`define CACHE_LINE_WIDTH      (`CACHE_LINE_SIZE*8)
