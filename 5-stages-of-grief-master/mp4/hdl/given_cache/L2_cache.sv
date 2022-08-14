module L2_cache (
  input clk,
  /* Physical memory signals */
  input logic pmem_resp,
  input logic [255:0] pmem_rdata,
  output logic [31:0] pmem_address,
  output logic [255:0] pmem_wdata,
  output logic pmem_read,
  output logic pmem_write,

  /* CPU memory signals */
  input logic mem_read,
  input logic mem_write,
  input logic [31:0] mem_byte_enable,
  input logic [31:0] mem_address,
  input logic [255:0] mem_wdata,
  output logic mem_resp,
  output logic [255:0] mem_rdata
);

logic tag_load;
logic valid_load;
logic dirty_load;
logic dirty_in;
logic dirty_out;

logic hit;
logic [1:0] writing;

cache_control control(.*);
cache_datapath datapath(.*);

endmodule : L2_cache
