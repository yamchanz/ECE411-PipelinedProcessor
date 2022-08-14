import rv32i_types::*;

module mp4 (
    input clk,
    input rst,
    input mem_resp,
    input [63:0] mem_rdata,
    output logic mem_read,
    output logic mem_write,
    output rv32i_word mem_addr,
    output [63:0] mem_wdata
);

// Signals between datapath and icache/dcache
// instruction cache
rv32i_word icache_rdata;
logic icache_resp;
logic icache_read;
rv32i_word icache_addr;
// data cache
rv32i_word dcache_rdata;
logic dcache_resp;
logic dcache_read;
logic dcache_write;
rv32i_word dcache_addr;
rv32i_word dcache_wdata;
logic [3:0] dcache_byte_enable;

// Signals between arbiter, prefetcher, L1/L2 icache
rv32i_word icache_pref_address;
logic icache_pref_read;
logic [255:0] pref_icache_rdata; 
logic pref_icache_resp;
// logic [255:0] arb_pref_rdata; 
// logic arb_pref_resp;
// rv32i_word pref_arb_address;
// logic pref_arb_read;
// rv32i_word L2_icache_addr; 
// logic L2_icache_read;
// logic [255:0] L2_icache_rdata;
// logic L2_icache_resp; 

// Signals between arbiter, eviction buffer, L1/L2 dcache
rv32i_word dcache_evb_address;
logic dcache_evb_write;
logic dcache_evb_read;
logic [255:0] dcache_evb_wdata;
logic [255:0] evb_dcache_rdata; 
logic evb_dcache_resp;
// logic [255:0] arb_evb_rdata; 
// logic arb_evb_resp;
// logic evb_arb_write; 
// logic evb_arb_read;
// rv32i_word evb_arb_address;
// logic [255:0] evb_arb_wdata;
// rv32i_word L2_dcache_addr; 
// logic L2_dcache_read;
// logic L2_dcache_write;
// logic [255:0] L2_dcache_rdata;
// logic [255:0] L2_dcache_wdata;
// logic L2_dcache_resp; 

datapath datapath(.*);

cache instr_cache(
    .clk(clk),
    // .pmem_resp(L2_icache_resp),
    // .pmem_rdata(L2_icache_rdata),
    // .pmem_wdata(),
    // .pmem_address(L2_icache_addr),
    // .pmem_read(L2_icache_read),
    .pmem_resp(pref_icache_resp),
    .pmem_rdata(pref_icache_rdata),
    .pmem_wdata(),
    .pmem_address(icache_pref_address),
    .pmem_read(icache_pref_read),
    .pmem_write(),
    .mem_read(icache_read),
    .mem_write(1'b0),
    .mem_byte_enable_cpu(4'd0),
    .mem_address(icache_addr),
    .mem_wdata_cpu(32'd0),
    .mem_resp(icache_resp),
    .mem_rdata_cpu(icache_rdata)
);

// L2_cache L2_instr_cache(
//     .clk(clk),
//     .pmem_resp(pref_icache_resp),
//     .pmem_rdata(pref_icache_rdata),
//     .pmem_wdata(),
//     .pmem_address(icache_pref_address),
//     .pmem_read(icache_pref_read),
//     .pmem_write(),
//     .mem_read(L2_icache_read),
//     .mem_write(1'b0),
//     .mem_byte_enable(32'hFFFFFFFF),
//     .mem_address(L2_icache_addr),
//     .mem_wdata(256'd0),
//     .mem_resp(L2_icache_resp),
//     .mem_rdata(L2_icache_rdata)
// );

// prefetcher pref(
//     .clk(clk),
//     .rst(rst),
//     .icache_pref_address(icache_pref_address), 
//     .icache_pref_read(icache_pref_read),
//     .pref_icache_rdata(pref_icache_rdata), 
//     .pref_icache_resp(pref_icache_resp), 
//     .arb_pref_rdata(arb_pref_rdata), 
//     .arb_pref_resp(arb_pref_resp),
//     .pref_arb_address(pref_arb_address),
//     .pref_arb_read(pref_arb_read)
// );

arbiter arbiter (
    .clk(clk),
    .rst(rst),
    // .instr_mem_addr(pref_arb_address),
    // .instr_mem_read(pref_arb_read), 
    // .instr_mem_read_data(arb_pref_rdata), 
    // .instr_mem_resp(arb_pref_resp),
    .instr_mem_addr(icache_pref_address),
    .instr_mem_read(icache_pref_read), 
    .instr_mem_read_data(pref_icache_rdata), 
    .instr_mem_resp(pref_icache_resp),
    .data_mem_addr(dcache_evb_address),
    .data_mem_read(dcache_evb_read), 
    .data_mem_write(dcache_evb_write),
    .data_mem_read_data(evb_dcache_rdata), 
    .data_mem_write_data(dcache_evb_wdata), 
    .data_mem_resp(evb_dcache_resp),
    .mem_read_data(mem_rdata), 
    .mem_resp(mem_resp),
    .mem_write(mem_write),
    .mem_read(mem_read),
    .mem_write_data(mem_wdata), 
    .mem_addr(mem_addr)
);

// eviction_buffer ev_buf(
//     .clk(clk),
//     .rst(rst), 
//     .dcache_evb_address(dcache_evb_address),
//     .dcache_evb_write(dcache_evb_write), 
//     .dcache_evb_read(dcache_evb_read), 
//     .dcache_evb_wdata(dcache_evb_wdata),
//     .evb_dcache_rdata(evb_dcache_rdata), 
//     .evb_dcache_resp(evb_dcache_resp), 
//     .arb_evb_rdata(arb_evb_rdata), 
//     .arb_evb_resp(arb_evb_resp), 
//     .evb_arb_write(evb_arb_write), 
//     .evb_arb_read(evb_arb_read), 
//     .evb_arb_address(evb_arb_address),
//     .evb_arb_wdata(evb_arb_wdata)
// );


// L2_cache L2_data_cache(
//     .clk(clk),
//     .pmem_resp(evb_dcache_resp),
//     .pmem_rdata(evb_dcache_rdata),
//     .pmem_address(dcache_evb_address),
//     .pmem_wdata(dcache_evb_wdata),
//     .pmem_read(dcache_evb_read),
//     .pmem_write(dcache_evb_write),
//     .mem_read(L2_dcache_read),
//     .mem_write(L2_dcache_write),
//     .mem_byte_enable(32'hFFFFFFFF),
//     .mem_address(L2_dcache_addr),
//     .mem_wdata(L2_dcache_wdata),
//     .mem_resp(L2_dcache_resp),
//     .mem_rdata(L2_dcache_rdata)
// );

cache data_cache(
    .clk(clk),
    // .pmem_resp(L2_dcache_resp),
    // .pmem_rdata(L2_dcache_rdata),
    // .pmem_address(L2_dcache_addr),
    // .pmem_wdata(L2_dcache_wdata),
    // .pmem_read(L2_dcache_read),
    // .pmem_write(L2_dcache_write),
    .pmem_resp(evb_dcache_resp),
    .pmem_rdata(evb_dcache_rdata),
    .pmem_address(dcache_evb_address),
    .pmem_wdata(dcache_evb_wdata),
    .pmem_read(dcache_evb_read),
    .pmem_write(dcache_evb_write),
    .mem_read(dcache_read),
    .mem_write(dcache_write),
    .mem_byte_enable_cpu(dcache_byte_enable),
    .mem_address(dcache_addr),
    .mem_wdata_cpu(dcache_wdata),
    .mem_resp(dcache_resp),
    .mem_rdata_cpu(dcache_rdata)
);

endmodule : mp4