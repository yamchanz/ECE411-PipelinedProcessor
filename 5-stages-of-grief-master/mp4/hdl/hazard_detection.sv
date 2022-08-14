import rv32i_types::*; 

module hazard_detection (
    input logic dcache_read, 
    input logic dcache_write,
    input logic dcache_resp,
    input logic icache_resp,
    input rv32i_opcode opcode,
    input logic j_en,
    input logic br_en, 
    input rv32i_reg src1,
    input rv32i_reg src2, 
    input rv32i_reg dest, 
    input logic m_ext_load,
    input logic m_ext_resp,
    output logic load_IF_ID, 
    output logic load_ID_EX, 
    output logic load_EX_MEM,
    output logic load_MEM_WB,
    output logic load_pc,
    output logic rst_IF_ID, 
    output logic rst_ID_EX,
    output logic rst_EX_MEM, 
    output logic rst_MEM_WB
);

logic [3:0] condition;
logic m_ext_wait, dcache_wait;

function void set_defaults();  
    load_IF_ID = 1'b1; 
    load_ID_EX = 1'b1; 
    load_EX_MEM = 1'b1;
    load_MEM_WB = 1'b1; 
    load_pc = 1'b1; 
    rst_IF_ID = 1'b0; 
    rst_ID_EX = 1'b0; 
    rst_EX_MEM = 1'b0;
    rst_MEM_WB = 1'b0;  
endfunction

function void stall(); 
    load_pc = 1'b0; 
    load_IF_ID = 1'b0; 
    load_ID_EX = 1'b0; 
    load_EX_MEM = 1'b0;
    load_MEM_WB = 1'b0; 
endfunction  

assign condition = {icache_resp, (dcache_read||dcache_write||m_ext_load), (dcache_resp||m_ext_resp), (j_en||(br_en&&(opcode==op_br)))};
assign m_ext_wait = (m_ext_load && !m_ext_resp) ? 1'b1 : 1'b0;
assign dcache_wait = (dcache_read && !dcache_resp) ? 1'b1 : 1'b0;

always_comb begin 
    set_defaults();
    unique case(condition)
        // wait instruction, no dcache access or m_ext, wait dcache or m_ext, no branch
        4'b0000: begin 
            load_pc = 1'b0; 
            rst_IF_ID = 1'b1; 
        end 
        // wait instruction, no dcache access or m_ext, wait dcache or m_ext, branch detected
        4'b0001: begin
            stall();
            rst_IF_ID = 1'b1; 
        end
        // wait instruction, no dcache access or m_ext, dcache data received or m_ext done, no branch -- impossible
        4'b0010:;
        // wait instruction, no dcache access or m_ext, dcache data received or m_ext done, branch detected -- impossible
        4'b0011:;
        // wait instruction, dcache access or m_ext load, wait dcache or m_ext, no branch
        4'b0100: stall();
        // wait instruction, dcache access or m_ext load, wait dcache or m_ext, branch detected
        4'b0101: begin
            stall();
            rst_IF_ID = 1'b1; 
        end
        // wait instruction, dcache access or m_ext load, dcache data received or m_ext done, no branch
        4'b0110: begin 
            load_pc = 1'b0;
            rst_IF_ID = 1'b1;
            if((dcache_read && m_ext_wait)||(m_ext_load && dcache_wait))
                stall();
        end 
        // wait instruction, dcache access or m_ext load, dcache data received or m_ext done, branch detected
        4'b0111: begin
            load_pc = 1'b0;
            load_ID_EX = 1'b0; 
            rst_IF_ID = 1'b1;
            if((dcache_read && m_ext_wait)||(m_ext_load && dcache_wait))
                stall();
        end
        // Instruction received, no dcache access or m_ext, wait dcache or m_ext, no branch
        4'b1000: ;
        // Instruction received, no dcache access or m_ext, wait dcache or m_ext, branch detected
        4'b1001:begin
            rst_IF_ID = 1'b1; 
            rst_ID_EX = 1'b1; 
        end
        // Instruction received, no dcache access or m_ext, dcache data received or m_ext done, no branch -- impossible
        4'b1010:;
        // Instruction received, no dcache access or m_ext, dcache data received or m_ext done, branch detected-- impossible
        4'b1011:;
        // Instruction received, dcache access or m_ext load, wait dcache or m_ext, no branch
        4'b1100: stall();
        // Instruction received, dcache access or m_ext load, wait dcache or m_ext, branch detected
        4'b1101: begin
            stall();
            rst_IF_ID = 1'b1;
        end
        // Instruction received, dcache access or m_ext load, dcache data received or m_ext done, no branch
        4'b1110:begin
            if((dcache_read && m_ext_wait)||(m_ext_load && dcache_wait))
                stall();
        end
        // Instruction received, dcache access, dcache data received, branch detected
        4'b1111: begin 
            load_ID_EX = 1'b0; 
            rst_IF_ID = 1'b1;
            if((dcache_read && m_ext_wait)||(m_ext_load && dcache_wait))
                stall();
        end 
    endcase 
end 
endmodule : hazard_detection