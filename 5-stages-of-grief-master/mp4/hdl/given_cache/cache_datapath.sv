module cache_datapath (
  input clk,

  /* CPU memory data signals */
  input logic  [31:0]  mem_byte_enable,
  input logic  [31:0]  mem_address,
  input logic  [255:0] mem_wdata,
  output logic [255:0] mem_rdata,

  /* Physical memory data signals */
  input  logic [255:0] pmem_rdata,
  output logic [255:0] pmem_wdata,
  output logic [31:0]  pmem_address,

  /* Control signals */
  input logic tag_load,
  input logic valid_load,
  input logic dirty_load,
  input logic dirty_in,
  output logic dirty_out,

  output logic hit,
  input logic [1:0] writing
);

logic [255:0] line_in[4];
logic [255:0] line_out[4];
logic [23:0] address_tag; 
logic [23:0] tag_out[4];
logic [2:0]  index;
logic [31:0] mask[4];
logic [3:0]valid_out;

logic tag_load_way [4]; 
logic valid_load_way [4];
logic dirty_load_way [4];
logic dirty_in_way [4];
logic dirty_out_way [4];
logic [2:0] lru_in; 
logic [2:0] lru_out[8] = '{default: '0}; 
logic [3:0] hit_way; 

assign hit_way[0] = valid_out[0] && (tag_out[0] == address_tag);
assign hit_way[1] = valid_out[1] && (tag_out[1] == address_tag);
assign hit_way[2] = valid_out[2] && (tag_out[2] == address_tag);
assign hit_way[3] = valid_out[3] && (tag_out[3] == address_tag);
assign hit = hit_way[0] || hit_way[1]  || hit_way[2]  || hit_way[3];
assign address_tag = mem_address[31:8];
assign index = mem_address[7:5];

function void way_initialize();
   for(int i=0; i<4; i++) begin 
    mask[i] = 32'd0; 
    line_in[i] = mem_wdata; 
    tag_load_way[i] = 1'b0; 
    valid_load_way[i] = 1'b0; 
    dirty_load_way[i] = 1'b0;
    dirty_in_way[i] = 1'b0; 
  end 
endfunction

function void load_from_mem(int idx);
  mask[idx] = 32'hFFFFFFFF;
  line_in[idx] = pmem_rdata; 
  tag_load_way[idx] = tag_load; 
  valid_load_way[idx] = valid_load; 
  dirty_load_way[idx] = dirty_load;
  dirty_in_way[idx] = dirty_in; 
endfunction

function void write_from_cpu(int idx);
  mask[idx] = mem_byte_enable; 
  line_in[idx] = mem_wdata; 
  tag_load_way[idx] = tag_load; 
  valid_load_way[idx] = valid_load; 
  dirty_load_way[idx] = dirty_load;
  dirty_in_way[idx] = dirty_in;
endfunction

function void set_pmem_dirty_out(int idx);
  dirty_out = dirty_out_way[idx];
  pmem_address = dirty_out_way[idx] ? {tag_out[idx], mem_address[7:0]} : mem_address;
  pmem_wdata = line_out[idx];
endfunction

// Cache array signal logic
always_comb begin
  way_initialize();
  case(writing)
    2'b00: begin // load from memory
      case(lru_out[index])
        3'b000, 3'b010: load_from_mem(0); // Replace way D 
        3'b001, 3'b011: load_from_mem(1); // Replace way C
        3'b100, 3'b101: load_from_mem(2); // Replace way B
        3'b110, 3'b111: load_from_mem(3); // Replace way A
        default:;
      endcase 
    end
    2'b01: begin // write from cpu
      case(hit_way)
        4'b0001: write_from_cpu(0);
        4'b0010: write_from_cpu(1); 
        4'b0100: write_from_cpu(2);
        4'b1000: write_from_cpu(3);
        default:;
      endcase
    end
    default:;
	endcase
end

// LRU logic
always_comb begin
    case(hit_way)
      4'b0001: lru_in = {1'b1, lru_out[index][1], 1'b1};
      4'b0010: lru_in = {1'b1, lru_out[index][1], 1'b0};
      4'b0100: lru_in = {1'b0, 1'b1, lru_out[index][0]};
      4'b1000: lru_in = {1'b0, 1'b0, lru_out[index][0]}; 
      default: lru_in = lru_out[index];
    endcase 
end

always_ff @ (posedge clk) begin 
    if(hit)
      lru_out[index] <= lru_in;
end 

// Cache output logic
always_comb begin
  case(hit_way) 
    4'b0001: mem_rdata = line_out[0];
    4'b0010: mem_rdata = line_out[1];
    4'b0100: mem_rdata = line_out[2];
    4'b1000: mem_rdata = line_out[3];
    default: mem_rdata = line_out[3]; 
  endcase 
end

always_comb begin
  dirty_out = 1'b0; 
  case(lru_out[index])
    3'b000, 3'b010: set_pmem_dirty_out(0); // Replace way D 
    3'b001, 3'b011: set_pmem_dirty_out(1); // Replace way C
    3'b100, 3'b101: set_pmem_dirty_out(2); // Replace way B
    3'b110, 3'b111: set_pmem_dirty_out(3); // Replace way A 
    default:; 
  endcase 
end 

// 4-way
data_array DM_cache_A (clk, mask[3], index, index, line_in[3], line_out[3]);
array #(24) tag_A (clk, tag_load_way[3], index, index, address_tag, tag_out[3]);
array #(1) valid_A (clk, valid_load_way[3], index, index, 1'b1, valid_out[3]);
array #(1) dirty_A (clk, dirty_load_way[3], index, index, dirty_in_way[3], dirty_out_way[3]);

data_array DM_cache_B (clk, mask[2], index, index, line_in[2], line_out[2]);
array #(24) tag_B (clk, tag_load_way[2], index, index, address_tag, tag_out[2]);
array #(1) valid_B (clk, valid_load_way[2], index, index, 1'b1, valid_out[2]);
array #(1) dirty_B (clk, dirty_load_way[2], index, index, dirty_in_way[2], dirty_out_way[2]);

data_array DM_cache_C (clk, mask[1], index, index, line_in[1], line_out[1]);
array #(24) tag_C (clk, tag_load_way[1], index, index, address_tag, tag_out[1]);
array #(1) valid_C (clk, valid_load_way[1], index, index, 1'b1, valid_out[1]);
array #(1) dirty_C (clk, dirty_load_way[1], index, index, dirty_in_way[1], dirty_out_way[1]);

data_array DM_cache_D (clk, mask[0], index, index, line_in[0], line_out[0]);
array #(24) tag_D (clk, tag_load_way[0], index, index, address_tag, tag_out[0]);
array #(1) valid_D (clk, valid_load_way[0], index, index, 1'b1, valid_out[0]);
array #(1) dirty_D (clk, dirty_load_way[0], index, index, dirty_in_way[0], dirty_out_way[0]);

endmodule : cache_datapath
