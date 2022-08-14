/* MODIFY. The cache datapath. It contains the data,
valid, dirty, tag, and LRU arrays, comparators, muxes,
logic gates and other supporting logic. */

module cache_datapath #(
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

    input logic [31:0] mem_address,
    //output logic [31:0] mem_rdata,
    //input logic [31:0] mem_wdata,

    //output logic [31:0] pmem_address
    input logic [255:0] pmem_rdata,
    //output logic [255:0] pmem_wdata,

    input logic [255:0] mem_wdata256,
    output logic [255:0] cacheline_out,
    input logic [31:0] mem_byte_enable256,

    // datapath -> control
    output logic hit1,
    output logic hit2,
    output logic old_block_dirty,
    output logic lru_out,
    output logic [23:0] tag1_out,
    output logic [23:0] tag2_out,
    output logic d1,
    output logic d2,
    // control -> datapath
    input logic ld_lru,
    input logic lru_in,
    input logic ld_tag1,
    input logic ld_tag2,
    input logic ld_valid1,
    input logic ld_valid2,
    input logic valid1_in,
    input logic valid2_in,
    input logic ld_dirty1,
    input logic ld_dirty2,
    input logic dirty1_in,
    input logic dirty2_in,
    input logic [1:0] write_en1_sel,
    input logic [1:0] write_en2_sel,
    input logic data_in_sel,
    input logic cacheline_out_sel 
);

logic [31:0] write_en1;
logic [255:0] data1_in ;
logic [255:0] data1_out;
logic [31:0] write_en2;
logic [255:0] data2_in;
logic [255:0] data2_out;
logic valid1_out;
logic valid2_out;
logic dirty1_out;
logic dirty2_out;
assign hit1 = ((mem_address[31:8] == tag1_out) & (valid1_out == 1'b1)) ? 1 : 0;
assign hit2 = ((mem_address[31:8] == tag2_out) & (valid2_out == 1'b1)) ? 1 : 0;
assign old_block_dirty = dirty1_out || dirty2_out;
assign d1 = dirty1_out;
assign d2 = dirty2_out;

array #(
    .s_index(3),
    .width(1)
)
LRU_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_lru),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(lru_in),
    .dataout(lru_out)
);

array #(
    .s_index(3),
    .width(24)
)
tag1_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_tag1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(mem_address[31:8]),
    .dataout(tag1_out)
);

array #(
    .s_index(3),
    .width(24)
)
tag2_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_tag2),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(mem_address[31:8]),
    .dataout(tag2_out)
);

data_array #(
    .s_offset(5),
    .s_index(3)
)
data1_arr (
    .clk(clk),
    .read(1'b1),
    .write_en(write_en1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(data1_in),
    .dataout(data1_out)
);

data_array #(
    .s_offset(5),
    .s_index(3)
)
data2_arr (
    .clk(clk),
    .read(1'b1),
    .write_en(write_en2),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(data2_in),
    .dataout(data2_out)
);

array #(
    .s_index(3),
    .width(1)
)
valid1_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_valid1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(valid1_in),
    .dataout(valid1_out)
);

array #(
    .s_index(3),
    .width(1)
)
valid2_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_valid2),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(valid2_in),
    .dataout(valid2_out)
);

array #(
    .s_index(3),
    .width(1)
)
dirty1_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_dirty1),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(dirty1_in),
    .dataout(dirty1_out)
);

array #(
    .s_index(3),
    .width(1)
)
dirty2_arr (
    .clk(clk),
    .rst(rst),
    .read(1'b1),
    .load(ld_dirty2),
    .rindex(mem_address[7:5]),
    .windex(mem_address[7:5]),
    .datain(dirty2_in),
    .dataout(dirty2_out)
);

always_comb begin: MUXES
    unique case(write_en1_sel)
        2'b00: write_en1 = 32'b0;
        2'b01: write_en1 = mem_byte_enable256;
        2'b11: write_en1 = {32{1'b1}};
        default: write_en1 = 32'b0;
    endcase

    unique case(write_en2_sel)
        2'b00: write_en2 = 32'b0;
        2'b01: write_en2 = mem_byte_enable256;
        2'b11: write_en2 = {32{1'b1}};
        default: write_en2 = 32'b0;
    endcase

    unique case(data_in_sel)
        1'b0: begin
            data1_in = mem_wdata256;
            data2_in = mem_wdata256;
        end
        1'b1: begin
            data1_in = pmem_rdata;
            data2_in = pmem_rdata;
        end
        default: ;
    endcase

    unique case(cacheline_out_sel)
        1'b0: cacheline_out = data1_out;
        1'b1: cacheline_out = data2_out;
        default: cacheline_out = data1_out;
    endcase 
end

endmodule : cache_datapath
