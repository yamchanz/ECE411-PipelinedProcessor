/* MODIFY. Your cache design. It contains the cache
controller, cache datapath, and bus adapter. */

module cache #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index,
    parameter s_mask   = 2**s_offset,
    parameter s_line   = 8*s_mask,
    parameter num_sets = 2**s_index
)
(
    input clk,
    input rst,

    /* CPU memory signals */
    input   logic [31:0]    mem_address,
    output  logic [31:0]    mem_rdata,
    input   logic [31:0]    mem_wdata,
    input   logic           mem_read,
    input   logic           mem_write,
    input   logic [3:0]     mem_byte_enable,
    output  logic           mem_resp,

    /* Physical memory signals */
    output  logic [31:0]    pmem_address,
    input   logic [255:0]   pmem_rdata,
    output  logic [255:0]   pmem_wdata,
    output  logic           pmem_read,
    output  logic           pmem_write,
    input   logic           pmem_resp
);

logic [255:0] cacheline_out;
logic [255:0] mem_rdata256;
logic [255:0] mem_wdata256;
logic [31:0] mem_byte_enable256;
assign pmem_wdata = cacheline_out;
assign mem_rdata256 = cacheline_out;

// datapath -> control
logic hit1;
logic hit2;
logic old_block_dirty;
logic lru_out = 1'b0;
logic [23:0] tag1_out;
logic [23:0] tag2_out;
logic d1;
logic d2;
// control -> datapath
logic ld_lru;
logic lru_in;
logic ld_tag1;
logic ld_tag2;
logic ld_valid1;
logic ld_valid2;
logic valid1_in;
logic valid2_in;
logic ld_dirty1;
logic ld_dirty2;
logic dirty1_in;
logic dirty2_in;
logic [1:0] write_en1_sel;
logic [1:0] write_en2_sel;
logic data_in_sel;
logic cacheline_out_sel; 

cache_control control
(
    .clk(clk),
    .rst(rst),

    .mem_address(mem_address),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .mem_resp(mem_resp),
    .mem_byte_enable(mem_byte_enable),
    
    .pmem_address(pmem_address),
    .pmem_read(pmem_read),
    .pmem_write(pmem_write),
    .pmem_resp(pmem_resp),

    .hit1(hit1),
    .hit2(hit2),
    .old_block_dirty(old_block_dirty),
    .lru_out(lru_out),
    .tag1_out(tag1_out),
    .tag2_out(tag2_out),

    .ld_lru(ld_lru),
    .lru_in(lru_in),
    .ld_tag1(ld_tag1),
    .ld_tag2(ld_tag2),
    .ld_valid1(ld_valid1),
    .ld_valid2(ld_valid2),
    .valid1_in(valid1_in),
    .valid2_in(valid2_in),
    .ld_dirty1(ld_dirty1),
    .ld_dirty2(ld_dirty2),
    .dirty1_in(dirty1_in),
    .dirty2_in(dirty2_in),
    .write_en1_sel(write_en1_sel),
    .write_en2_sel(write_en2_sel),
    .data_in_sel(data_in_sel),
    .cacheline_out_sel(cacheline_out_sel),

    .d1(d1),
    .d2(d2)
);

cache_datapath datapath
(
    .clk(clk),
    .rst(rst),

    .mem_address(mem_address),
    
    .pmem_rdata(pmem_rdata),
    .mem_wdata256(mem_wdata256),

    .cacheline_out(cacheline_out),

    .mem_byte_enable256(mem_byte_enable256),

    .hit1(hit1),
    .hit2(hit2),
    .old_block_dirty(old_block_dirty),
    .lru_out(lru_out),
    .tag1_out(tag1_out),
    .tag2_out(tag2_out),

    .ld_lru(ld_lru),
    .lru_in(lru_in),
    .ld_tag1(ld_tag1),
    .ld_tag2(ld_tag2),
    .ld_valid1(ld_valid1),
    .ld_valid2(ld_valid2),
    .valid1_in(valid1_in),
    .valid2_in(valid2_in),
    .ld_dirty1(ld_dirty1),
    .ld_dirty2(ld_dirty2),
    .dirty1_in(dirty1_in),
    .dirty2_in(dirty2_in),
    .write_en1_sel(write_en1_sel),
    .write_en2_sel(write_en2_sel),
    .data_in_sel(data_in_sel),
    .cacheline_out_sel(cacheline_out_sel),

    .d1(d1),
    .d2(d2)
);

bus_adapter bus_adapter
(
    .mem_wdata256(mem_wdata256),
    .mem_rdata256(mem_rdata256),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_byte_enable(mem_byte_enable),
    .mem_byte_enable256(mem_byte_enable256),
    .address(mem_address)
);

endmodule : cache
