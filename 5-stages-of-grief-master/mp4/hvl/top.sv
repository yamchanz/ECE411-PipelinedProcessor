import rv32i_types::*; 
module mp4_tb;
`timescale 1ns/10ps

/********************* Do not touch for proper compilation *******************/
// Instantiate Interfaces
tb_itf itf();
rvfi_itf rvfi(itf.clk, itf.rst);

// Instantiate Testbench
source_tb tb(
    .magic_mem_itf(itf),
    .mem_itf(itf),
    .sm_itf(itf),
    .tb_itf(itf),
    .rvfi(rvfi)
);

// For local simulation, add signal for Modelsim to display by default
// Note that this signal does nothing and is not used for anything
// bit f;
// logic commit;

/****************************** End do not touch *****************************/

/************************ Signals necessary for monitor **********************/
// This section not required until CP2

//assign rvfi.commit = 0; // Set high when a valid instruction is modifying regfile or PC
//assign rvfi.halt = 0;
/*always_ff @(posedge itf.clk) begin
    if(itf.rst) begin
        commit <= 0;
    end else begin
        commit <= dut.datapath.load_MEM_WB;
    end
end*/

// assign rvfi.commit = commit && dut.datapath.MEM_WB_output.control_word.opcode != 0;
// assign rvfi.halt =  dut.datapath.load_pc && (dut.datapath.pc_out == dut.datapath.EX_MEM_output.data_word.pc) &&
//                     (dut.datapath.MEM_WB_output.control_word.opcode == 0) && 
//                     (dut.datapath.EX_MEM_output.control_word.br_en == 1 || 
//                     dut.datapath.EX_MEM_output.control_word.opcode == op_jal ||
//                     dut.datapath.EX_MEM_output.control_word.opcode == op_jalr);
assign rvfi.commit = 0;
assign rvfi.halt = 0;
initial rvfi.order = 0;
always @(posedge itf.clk iff rvfi.commit) rvfi.order <= rvfi.order + 1; // Modify for OoO


// //Instruction and trap:
// assign rvfi.inst = dut.datapath.inst_MEM_WB_out;
// assign rvfi.trap = dut.datapath.trap; //0 will be fine

// //Regfile:
// assign rvfi.rs1_addr = dut.datapath.MEM_WB_output.data_word.rs1;
// assign rvfi.rs2_addr = dut.datapath.MEM_WB_output.data_word.rs2;
// assign rvfi.rs1_rdata = dut.datapath.MEM_WB_output.data_word.rs1_out;
// assign rvfi.rs2_rdata = dut.datapath.MEM_WB_output.data_word.rs2_out;
// assign rvfi.load_regfile = dut.datapath.MEM_WB_output.control_word.load_regfile;
// assign rvfi.rd_addr = dut.datapath.MEM_WB_output.data_word.rd;
// assign rvfi.rd_wdata = dut.datapath.regfilemux_out;

// //PC:
// assign rvfi.pc_rdata = dut.datapath.MEM_WB_output.data_word.pc;
// assign rvfi.pc_wdata = dut.datapath.PC_MEM_WB_out;

// //Memory:
// assign rvfi.mem_addr = {dut.datapath.MEM_WB_output.data_word.alu_out[31:2], 2'b00};
// assign rvfi.mem_rmask = dut.datapath.rmask;
// assign rvfi.mem_wmask = dut.datapath.wmask;
// assign rvfi.mem_rdata = dut.datapath.MEM_WB_output.data_word.mdr_out;
// assign rvfi.mem_wdata = dut.datapath.MEM_WB_output.data_word.rs2_out << (8 * dut.datapath.MEM_WB_output.data_word.alu_out[1:0]);

//Please refer to rvfi_itf.sv for more information.

/**************************** End RVFIMON signals ****************************/

/********************* Assign Shadow Memory Signals Here *********************/
//icache signals:
assign itf.inst_read = dut.icache_read;
assign itf.inst_addr = dut.icache_addr; 
assign itf.inst_rdata= dut.icache_rdata;
assign itf.inst_resp = dut.icache_resp;

//dcache signals:
assign itf.data_read = dut.dcache_read;
assign itf.data_write= dut.dcache_write;
assign itf.data_addr = dut.dcache_addr;
assign itf.data_rdata= dut.dcache_rdata;
assign itf.data_wdata= dut.dcache_wdata;
assign itf.data_resp = dut.dcache_resp;
assign itf.data_mbe  = dut.dcache_byte_enable;

//Please refer to tb_itf.sv for more information.


/*********************** End Shadow Memory Assignments ***********************/

// Set this to the proper value
assign itf.registers = '{default: '0};

/*********************** Instantiate your design here ************************/
mp4 dut(
    .clk(itf.clk),
    .rst(itf.rst),
    .mem_resp(itf.mem_resp),
    .mem_rdata(itf.mem_rdata),
    .mem_read(itf.mem_read),
    .mem_write(itf.mem_write),
    .mem_addr(itf.mem_addr),
    .mem_wdata(itf.mem_wdata)
);


/***************************** End Instantiation *****************************/

/*********************** Performance Counter  ************************/
// int t = 168290; // CP2 : 806, CP3: 168290
// int num_branch = 0;
// int num_taken = 0;
// int num_predicted_t = 0;
// int num_predicted_nt = 0;
// int num_missed = 0;

// always @(posedge itf.clk) begin
//     if (t == 0) begin
//         $display("********* Number of Branches: %0d ***********", num_branch);
//         $display("********* Number of Branches Predicted Taken: %0d ***********", num_predicted_t);
//         $display("********* Number of Branches Predicted Not Taken: %0d ***********", num_predicted_nt);
//         $display("********* Number of Branches Actually Taken: %0d ***********", num_taken);
//         $display("********* Number of Branches Actually Not Taken: %0d ***********", num_branch-num_taken);
//         $display("********* Number of Branch Missed: %0d ***********", num_missed);
//     end

//     if ((dut.datapath.EX_MEM_input.control_word.opcode == op_br)
//     && dut.datapath.load_EX_MEM) begin
//         num_branch <= num_branch + 1;
//     end

//     if ((dut.datapath.IF_ID_input.control_word.opcode == op_br)
//     && dut.datapath.load_IF_ID && ~dut.datapath.rst_IF_ID) begin
//         if (num_missed < num_taken - num_predicted_t)
//             num_missed <= num_missed + 1;
//         if (dut.datapath.tournament.prediction == 1'b0)
//             num_predicted_nt <= num_predicted_nt + 1;
//         else if (dut.datapath.tournament.prediction == 1'b1)
//             num_predicted_t <= num_predicted_t + 1;
//     end

//     if (dut.datapath.br_en == 1'b1 && dut.datapath.EX_MEM_input.control_word.opcode == op_br
//     && dut.datapath.load_EX_MEM) begin
//         num_taken <= num_taken + 1;
//     end
    
//     if ((dut.datapath.tournament.miss == 1'b1)
//      && (dut.datapath.EX_MEM_input.control_word.opcode == op_br)
//      && ~dut.datapath.rst_IF_ID) begin
//         num_missed <= num_missed + 1;  
//     end

//     t <= t - 1;
// end

// logic [31:0] prefetcher_performance_counter;

// always_ff @(posedge itf.clk) begin
//     if(itf.rst)
//         prefetcher_performance_counter <= 32'd0;
//     else if(dut.pref.pref_icache_resp)
//         prefetcher_performance_counter <= prefetcher_performance_counter + 32'd1;
//     else
//         prefetcher_performance_counter <= prefetcher_performance_counter;
// end


// logic [31:0] evb_performance_counter;
// always_ff @(posedge itf.clk) begin
//     if(itf.rst)
//         evb_performance_counter <= 32'd0;
//     else if(dut.ev_buf.evb_dcache_resp)
//         evb_performance_counter <= evb_performance_counter + 32'd1;
//     else
//         evb_performance_counter <= evb_performance_counter;
// end


// logic [31:0] L1_icache_hit_counter =  '{default: '0};
// logic [31:0] L1_icache_miss_counter = '{default: '0};
// always_ff @ (posedge itf.clk) begin 
//   if (dut.instr_cache.datapath.hit) 
//     L1_icache_hit_counter <= L1_icache_hit_counter + 32'd1; 
//   if (dut.instr_cache.datapath.tag_load)
//     L1_icache_miss_counter <= L1_icache_miss_counter + 32'd1; 
// end 

// logic [31:0] L1_dcache_hit_counter =  '{default: '0};
// logic [31:0] L1_dcache_miss_counter = '{default: '0};
// always_ff @ (posedge itf.clk) begin 
//   if (dut.data_cache.datapath.hit) 
//     L1_dcache_hit_counter <= L1_dcache_hit_counter + 32'd1; 
//   if (dut.data_cache.datapath.tag_load)
//     L1_dcache_miss_counter <= L1_dcache_miss_counter + 32'd1; 
// end 

// logic [31:0] L2_icache_hit_counter =  '{default: '0};
// logic [31:0] L2_icache_miss_counter = '{default: '0};
// always_ff @ (posedge itf.clk) begin 
//   if (dut.L2_instr_cache.datapath.hit) 
//     L2_icache_hit_counter <= L2_icache_hit_counter + 32'd1; 
//   if (dut.L2_instr_cache.datapath.tag_load)
//     L2_icache_miss_counter <= L2_icache_miss_counter + 32'd1; 
// end 

// logic [31:0] L2_dcache_hit_counter =  '{default: '0};
// logic [31:0] L2_dcache_miss_counter = '{default: '0};
// always_ff @ (posedge itf.clk) begin 
//   if (dut.L2_data_cache.datapath.hit) 
//     L2_dcache_hit_counter <= L2_dcache_hit_counter + 32'd1; 
//   if (dut.L2_data_cache.datapath.tag_load)
//     L2_dcache_miss_counter <= L2_dcache_miss_counter + 32'd1; 
// end 

// logic [31:0] m_ext_performance_counter;
// always_ff @(posedge itf.clk) begin
//     if(itf.rst)
//         m_ext_performance_counter <= 32'd0;
//     else if(dut.datapath.m_ext_resp)
//         m_ext_performance_counter <= m_ext_performance_counter + 32'd1;
//     else
//         m_ext_performance_counter <= m_ext_performance_counter;
// end
/*********************** End Performance Counter ************************/



endmodule