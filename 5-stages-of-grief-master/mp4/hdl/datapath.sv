import rv32i_types::*; 

module datapath(
    input clk,
    input rst,
    // instruction cache
    input rv32i_word icache_rdata,
    input icache_resp,
    output logic icache_read,
    output rv32i_word icache_addr,
    // data cache
    input rv32i_word dcache_rdata,
    input dcache_resp,
    output logic dcache_read,
    output logic dcache_write,
    output rv32i_word dcache_addr,
    output rv32i_word dcache_wdata,
    output logic [3:0] dcache_byte_enable
);

rv32i_reg rd;
rv32i_word rs1_out;
rv32i_word rs2_out;
rv32i_word pcmux_out;
rv32i_word alumux1_out;
rv32i_word alumux2_out;
rv32i_word regfilemux_out;
rv32i_word cmpmux1_out; 
rv32i_word cmpmux2_out;
rv32i_word alu_out;
rv32i_word pc_out;
logic [2:0] pc_mux_sel;
logic alumux2_sel;
logic [2:0] alu_mux1_sel;
logic [2:0] alu_mux2_sel;
logic [2:0] cmp_mux1_sel;
logic [2:0] cmp_mux2_sel;
logic [1:0] mask; 

rv32i_stage_reg IF_ID_input; 
rv32i_stage_reg IF_ID_output; 
rv32i_stage_reg ID_EX_input; 
rv32i_stage_reg ID_EX_output;
rv32i_stage_reg EX_MEM_input; 
rv32i_stage_reg EX_MEM_output;
rv32i_stage_reg MEM_WB_input; 
rv32i_stage_reg MEM_WB_output;

logic EX_MEM_store_forwarding;
rv32i_word EX_MEM_rs2_forwarding;  
rv32i_word EX_MEM_alumux1_forwarding;
rv32i_word EX_MEM_alumux2_forwarding;
rv32i_word EX_MEM_cmpmux1_forwarding;
rv32i_word EX_MEM_cmpmux2_forwarding;
rv32i_word MEM_WB_alumux1_forwarding;
rv32i_word MEM_WB_alumux2_forwarding;
rv32i_word MEM_WB_cmpmux1_forwarding;
rv32i_word MEM_WB_cmpmux2_forwarding;
logic [1:0] alumux1_sel_forwarding;
logic [1:0] alumux2_sel_forwarding;
logic [1:0] cmpmux1_sel_forwarding;
logic [1:0] cmpmux2_sel_forwarding;

logic br_en;
logic br_en_cmp;
logic j_en; 
logic load_pc;
logic load_IF_ID; 
logic load_ID_EX;
logic load_EX_MEM;
logic load_MEM_WB;
logic rst_IF_ID;
logic rst_ID_EX;
logic rst_EX_MEM; 
logic rst_MEM_WB;

logic m_ext_load;
logic m_ext_resp;
rv32i_word m_ext_out;

logic prediction;
logic miss;

/**********************************IF***********************************/
assign icache_addr = pc_out; 
assign icache_read = 1'b1;

pc_register PC(
    .clk(clk),
    .rst(rst),
    .load(load_pc),
    .in(pcmux_out),
    .out(pc_out)
);

control_rom ctrl_rom (
    .opcode(rv32i_opcode'(icache_rdata[6:0])), 
    .funct3(icache_rdata[14:12]), 
    .funct7(icache_rdata[31:25]), 
    .ctrl(IF_ID_input.control_word)
);

always_comb begin
    IF_ID_input.data_word.pc = pc_out; 
    IF_ID_input.data_word.rs1 = icache_rdata[19:15]; 
    IF_ID_input.data_word.rs2 = icache_rdata[24:20]; 
    IF_ID_input.data_word.rd = icache_rdata[11:7]; 
    IF_ID_input.data_word.rs1_out = 32'd0; 
    IF_ID_input.data_word.rs2_out = 32'd0; 
    IF_ID_input.data_word.alu_out = 32'd0; 
    IF_ID_input.data_word.mdr_out = 32'd0; 
    // Instruction immediates parse
    unique case(IF_ID_input.control_word.opcode) 
        op_jalr, op_load, op_imm: begin
            IF_ID_input.data_word.imm = {{21{icache_rdata[31]}}, icache_rdata[30:20]};
            IF_ID_input.data_word.rs2 = 5'd0;
        end
        op_store: IF_ID_input.data_word.imm = {{21{icache_rdata[31]}}, icache_rdata[30:25], icache_rdata[11:7]};
        op_br: IF_ID_input.data_word.imm = {{20{icache_rdata[31]}}, icache_rdata[7], icache_rdata[30:25], icache_rdata[11:8], 1'b0};
        op_lui, op_auipc: begin
            IF_ID_input.data_word.imm = {icache_rdata[31:12], 12'd0};
            IF_ID_input.data_word.rs1 = 5'd0; 
            IF_ID_input.data_word.rs2 = 5'd0;
        end
        op_jal: begin
            IF_ID_input.data_word.imm = {{12{icache_rdata[31]}}, icache_rdata[19:12], icache_rdata[20], icache_rdata[30:21], 1'b0};
            IF_ID_input.data_word.rs1 = 5'd0; 
            IF_ID_input.data_word.rs2 = 5'd0;
        end
        default: IF_ID_input.data_word.imm = 32'd0;
    endcase 
    // Branch condition
    j_en = (EX_MEM_input.control_word.opcode == op_jal || EX_MEM_input.control_word.opcode == op_jalr);
    // if (prediction == 1'b1 && IF_ID_input.control_word.opcode == op_br)
    //     pc_mux_sel = 3'b111;
    // else
    pc_mux_sel = {1'b0, {j_en, (br_en_cmp && EX_MEM_input.control_word.opcode == op_br)}};
    // pcmux
    unique case(pc_mux_sel)
        pcmux::pc_plus4:   pcmux_out = pc_out + 4; 
        pcmux::alu_out:    pcmux_out = EX_MEM_input.data_word.alu_out; 
        pcmux::alu_mod2:   pcmux_out = {EX_MEM_input.data_word.alu_out[31:1], 1'b0};
        pcmux::br_en:      pcmux_out = pc_out + 4;
        pcmux::br_predict: pcmux_out = pc_out + IF_ID_input.data_word.imm;
        default: pcmux_out = pc_out + 4;
    endcase 
end

/*********************************IF_ID********************************/
stage_register IF_ID (
    .clk(clk), 
    .rst(rst_IF_ID), 
    .load(load_IF_ID),
    .input_word(IF_ID_input),
    .output_word(IF_ID_output)
); 

/**********************************ID**********************************/
regfile regfile (
    .clk(clk), 
    .rst(rst), 
    .load(MEM_WB_output.control_word.load_regfile), 
    .in(regfilemux_out),
    .src_a(IF_ID_output.data_word.rs1),
    .src_b(IF_ID_output.data_word.rs2), 
    .dest(MEM_WB_output.data_word.rd),
    .reg_a(ID_EX_input.data_word.rs1_out),
    .reg_b(ID_EX_input.data_word.rs2_out)
);


always_comb begin
    // Bypass unchanged signals
    ID_EX_input.control_word = IF_ID_output.control_word;
    ID_EX_input.data_word.pc = IF_ID_output.data_word.pc; 
    ID_EX_input.data_word.imm = IF_ID_output.data_word.imm;
    ID_EX_input.data_word.rs1 = IF_ID_output.data_word.rs1;
    ID_EX_input.data_word.rs2 = IF_ID_output.data_word.rs2;  
    ID_EX_input.data_word.rd = IF_ID_output.data_word.rd; 
    ID_EX_input.data_word.alu_out = IF_ID_output.data_word.alu_out;
    ID_EX_input.data_word.mdr_out = IF_ID_output.data_word.mdr_out; 
    // regfilemux for WB
    unique case(MEM_WB_output.control_word.regfilemux_sel)
        regfilemux::alu_out:  regfilemux_out = MEM_WB_output.data_word.alu_out; 
        regfilemux::br_en:    regfilemux_out = {31'd0, MEM_WB_output.control_word.br_en}; 
        regfilemux::u_imm:    regfilemux_out = MEM_WB_output.data_word.imm; 
        regfilemux::pc_plus4: regfilemux_out = MEM_WB_output.data_word.pc + 4;
        regfilemux::lw:       regfilemux_out = MEM_WB_output.data_word.mdr_out;
        regfilemux::lh:       regfilemux_out = MEM_WB_output.data_word.mdr_out; 
        regfilemux::lhu:      regfilemux_out = MEM_WB_output.data_word.mdr_out; 
        regfilemux::lb:       regfilemux_out = MEM_WB_output.data_word.mdr_out; 
        regfilemux::lbu:      regfilemux_out = MEM_WB_output.data_word.mdr_out; 
        default: ;
    endcase     
end

/*********************************ID_EX********************************/
stage_register ID_EX (
    .clk(clk), 
    .rst(rst_ID_EX), 
    .load(load_ID_EX),
    .input_word(ID_EX_input),
    .output_word(ID_EX_output)
); 

/**********************************EX**********************************/
alu ALU (
    .aluop(ID_EX_output.control_word.aluop), 
    .a(alumux1_out), 
    .b(alumux2_out),
    .f(alu_out)
);

cmp CMP (
    .cmp_mux1_out(cmpmux1_out),
    .cmp_mux2_out(cmpmux2_out),
    .cmpop(ID_EX_output.control_word.cmpop), 
    .cmp_out(br_en_cmp)
);

assign br_en = ((!dcache_resp) && (EX_MEM_output.control_word.opcode == op_load)) ? 1'b0 : 
               ((EX_MEM_output.control_word.opcode == 7'd0) && (MEM_WB_output.control_word.opcode == op_load)) ? 1'b0 :
               br_en_cmp && (ID_EX_output.control_word.opcode == op_br || ((ID_EX_output.control_word.opcode == op_reg || ID_EX_output.control_word.opcode == op_imm) && (ID_EX_output.control_word.funct3 == 3'd2 || ID_EX_output.control_word.funct3 == 3'd3)));

always_comb begin
    // Bypass unchanged signals
    EX_MEM_input.control_word.opcode = ID_EX_output.control_word.opcode;
    EX_MEM_input.control_word.aluop = ID_EX_output.control_word.aluop;
    EX_MEM_input.control_word.regfilemux_sel = ID_EX_output.control_word.regfilemux_sel;
    EX_MEM_input.control_word.load_regfile = ID_EX_output.control_word.load_regfile;
    EX_MEM_input.control_word.alumux1_sel = ID_EX_output.control_word.alumux1_sel;
    EX_MEM_input.control_word.cmpmux_sel = ID_EX_output.control_word.cmpmux_sel;
    EX_MEM_input.control_word.cmpop = ID_EX_output.control_word.cmpop;
    EX_MEM_input.control_word.dcache_read = ID_EX_output.control_word.dcache_read;
    EX_MEM_input.control_word.dcache_write = ID_EX_output.control_word.dcache_write;
    EX_MEM_input.control_word.funct3 = ID_EX_output.control_word.funct3;
    EX_MEM_input.control_word.funct7 = ID_EX_output.control_word.funct7;
    EX_MEM_input.control_word.br_en = br_en;
    EX_MEM_input.data_word.pc = ID_EX_output.data_word.pc; 
    EX_MEM_input.data_word.imm = ID_EX_output.data_word.imm;
    EX_MEM_input.data_word.rs1 = ID_EX_output.data_word.rs1;
    EX_MEM_input.data_word.rs2 = ID_EX_output.data_word.rs2;  
    EX_MEM_input.data_word.rd = ID_EX_output.data_word.rd; 
    EX_MEM_input.data_word.rs1_out = ID_EX_output.data_word.rs1_out;
    EX_MEM_input.data_word.rs2_out = (EX_MEM_store_forwarding) ? EX_MEM_rs2_forwarding : ID_EX_output.data_word.rs2_out;
    EX_MEM_input.data_word.alu_out = m_ext_load ? m_ext_out : alu_out;
    EX_MEM_input.data_word.mdr_out = ID_EX_output.data_word.mdr_out; 
    // alumux1
    alu_mux1_sel = {alumux1_sel_forwarding, ID_EX_output.control_word.alumux1_sel};
    unique case(alu_mux1_sel) 
        3'b000: alumux1_out = ID_EX_output.data_word.rs1_out;
        3'b001: alumux1_out = ID_EX_output.data_word.pc;
        3'b010: alumux1_out = EX_MEM_alumux1_forwarding;  
        3'b011: alumux1_out = EX_MEM_alumux1_forwarding;
        3'b100: alumux1_out = ID_EX_output.data_word.rs1_out;
        3'b101: alumux1_out = ID_EX_output.data_word.pc;
        3'b110: alumux1_out = MEM_WB_alumux1_forwarding;
        3'b111: alumux1_out = MEM_WB_alumux1_forwarding;
        default:;
    endcase
    // alumux2
    alumux2_sel = (ID_EX_output.control_word.opcode == op_reg) ? 1'b1 : 1'b0;
    alu_mux2_sel = {alumux2_sel_forwarding, alumux2_sel};
    unique case(alu_mux2_sel) 
        3'b000: alumux2_out = ID_EX_output.data_word.imm;
        3'b001: alumux2_out = ID_EX_output.data_word.rs2_out;
        3'b010: alumux2_out = ID_EX_output.data_word.imm;
        3'b011: alumux2_out = EX_MEM_alumux2_forwarding;
        3'b100: alumux2_out = ID_EX_output.data_word.imm;
        3'b101: alumux2_out = ID_EX_output.data_word.rs2_out;
        3'b110: alumux2_out = ID_EX_output.data_word.imm;
        3'b111: alumux2_out = MEM_WB_alumux2_forwarding;
        default:;
    endcase  
    // cmpmux1
    cmp_mux1_sel = cmpmux1_sel_forwarding;
    unique case(cmp_mux1_sel)
        2'b00: cmpmux1_out = ID_EX_output.data_word.rs1_out;
        2'b01: cmpmux1_out = EX_MEM_cmpmux1_forwarding;
        2'b10: cmpmux1_out = ID_EX_output.data_word.rs1_out;
        2'b11: cmpmux1_out = MEM_WB_cmpmux1_forwarding;
        default:;
    endcase
    // cmpmux2
    cmp_mux2_sel = {cmpmux2_sel_forwarding, ID_EX_output.control_word.cmpmux_sel};
    unique case(cmp_mux2_sel)
        3'b000: cmpmux2_out = ID_EX_output.data_word.rs2_out;
        3'b001: cmpmux2_out = ID_EX_output.data_word.imm;
        3'b010: cmpmux2_out = EX_MEM_cmpmux2_forwarding;
        3'b011: cmpmux2_out = EX_MEM_cmpmux2_forwarding;
        3'b100: cmpmux2_out = ID_EX_output.data_word.rs2_out;
        3'b101: cmpmux2_out = ID_EX_output.data_word.imm;
        3'b110: cmpmux2_out = MEM_WB_cmpmux2_forwarding;
        3'b111: cmpmux2_out = MEM_WB_cmpmux2_forwarding;
        default:;
    endcase     
    // dcache_byte_enable calculation for store instruction
    unique case(store_funct3_t'(ID_EX_output.control_word.funct3))
        sw: EX_MEM_input.control_word.dcache_byte_enable = 4'b1111;
        sh: EX_MEM_input.control_word.dcache_byte_enable = 4'b0011 << EX_MEM_input.data_word.alu_out[1:0];
        sb: EX_MEM_input.control_word.dcache_byte_enable = 4'b0001 << EX_MEM_input.data_word.alu_out[1:0];
        default: EX_MEM_input.control_word.dcache_byte_enable = 4'b1111; 
    endcase 
end

/********************************EX_MEM********************************/
stage_register EX_MEM (
    .clk(clk), 
    .rst(rst_EX_MEM), 
    .load(load_EX_MEM),
    .input_word(EX_MEM_input),
    .output_word(EX_MEM_output)
); 

/*********************************MEM**********************************/
// dcache output signal
always_comb begin
    dcache_addr = {EX_MEM_output.data_word.alu_out[31:2], 2'b00}; 
    dcache_read = EX_MEM_output.control_word.dcache_read;
    dcache_write = EX_MEM_output.control_word.dcache_write;  
    dcache_wdata = EX_MEM_output.data_word.rs2_out << (8 * EX_MEM_output.data_word.alu_out[1:0]);  
    dcache_byte_enable = EX_MEM_output.control_word.dcache_byte_enable;
end

always_comb begin
    // Bypass unchanged signals
    MEM_WB_input.control_word.load_regfile = EX_MEM_output.control_word.load_regfile;
    MEM_WB_input.control_word.regfilemux_sel = EX_MEM_output.control_word.regfilemux_sel;
    MEM_WB_input.control_word.cmpmux_sel = EX_MEM_output.control_word.cmpmux_sel;
    MEM_WB_input.control_word.alumux1_sel = EX_MEM_output.control_word.alumux1_sel;
    MEM_WB_input.control_word.aluop = EX_MEM_output.control_word.aluop;
    MEM_WB_input.control_word.cmpop = EX_MEM_output.control_word.cmpop;
    MEM_WB_input.control_word.dcache_read = EX_MEM_output.control_word.dcache_read;
    MEM_WB_input.control_word.dcache_write = EX_MEM_output.control_word.dcache_write;
    MEM_WB_input.control_word.dcache_byte_enable = EX_MEM_output.control_word.dcache_byte_enable;
    MEM_WB_input.control_word.opcode = EX_MEM_output.control_word.opcode;
    MEM_WB_input.control_word.funct3 = EX_MEM_output.control_word.funct3;
    MEM_WB_input.control_word.funct7 = EX_MEM_output.control_word.funct7;
    MEM_WB_input.control_word.br_en = EX_MEM_output.control_word.br_en;
    MEM_WB_input.data_word.pc = EX_MEM_output.data_word.pc; 
    MEM_WB_input.data_word.rs1 = EX_MEM_output.data_word.rs1;
    MEM_WB_input.data_word.rs2 = EX_MEM_output.data_word.rs2;  
    MEM_WB_input.data_word.rd = EX_MEM_output.data_word.rd; 
    MEM_WB_input.data_word.rs1_out = EX_MEM_output.data_word.rs1_out;
    MEM_WB_input.data_word.rs2_out = EX_MEM_output.data_word.rs2_out;
    MEM_WB_input.data_word.alu_out = EX_MEM_output.data_word.alu_out;
    MEM_WB_input.data_word.imm = EX_MEM_output.data_word.imm;  
    MEM_WB_input.data_word.mdr_out = dcache_rdata; 
    mask = EX_MEM_output.data_word.alu_out[1:0]; 
    // regfilemux
    unique case(MEM_WB_input.control_word.regfilemux_sel)
        regfilemux::lh: begin 
            unique case(mask)
                2'b00: MEM_WB_input.data_word.mdr_out = {{16{dcache_rdata[15]}}, dcache_rdata[15:0]};
                2'b01: MEM_WB_input.data_word.mdr_out = {{16{dcache_rdata[23]}}, dcache_rdata[23:8]};
                2'b10: MEM_WB_input.data_word.mdr_out = {{16{dcache_rdata[31]}}, dcache_rdata[31:16]}; 
                2'b11: MEM_WB_input.data_word.mdr_out = 32'd0;
            endcase 
        end  
        regfilemux::lhu: begin 
            unique case(mask)
                2'b00: MEM_WB_input.data_word.mdr_out = {16'd0, dcache_rdata[15:0]};
                2'b01: MEM_WB_input.data_word.mdr_out = {16'd0, dcache_rdata[23:8]};
                2'b10: MEM_WB_input.data_word.mdr_out = {16'd0, dcache_rdata[31:16]}; 
                2'b11: MEM_WB_input.data_word.mdr_out = 32'd0;
            endcase 
        end
        regfilemux::lb: begin 
            unique case(mask)
                2'b00: MEM_WB_input.data_word.mdr_out = {{24{dcache_rdata[7]}},  dcache_rdata[7:0]}; 
                2'b01: MEM_WB_input.data_word.mdr_out = {{24{dcache_rdata[15]}}, dcache_rdata[15:8]};
                2'b10: MEM_WB_input.data_word.mdr_out = {{24{dcache_rdata[23]}}, dcache_rdata[23:16]};
                2'b11: MEM_WB_input.data_word.mdr_out = {{24{dcache_rdata[31]}}, dcache_rdata[31:24]};                
            endcase
        end 
        regfilemux::lbu: begin 
            unique case(mask)
                2'b00: MEM_WB_input.data_word.mdr_out = {24'd0, dcache_rdata[7:0]}; 
                2'b01: MEM_WB_input.data_word.mdr_out = {24'd0, dcache_rdata[15:8]};
                2'b10: MEM_WB_input.data_word.mdr_out = {24'd0, dcache_rdata[23:16]};
                2'b11: MEM_WB_input.data_word.mdr_out = {24'd0, dcache_rdata[31:24]};
            endcase              
        end    
        default: ;
    endcase                   
end

/********************************MEM_WB********************************/
stage_register MEM_WB (
    .clk(clk), 
    .rst(rst_MEM_WB), 
    .load(load_MEM_WB),
    .input_word(MEM_WB_input),
    .output_word(MEM_WB_output)
);  

/******************************FORWARDING******************************/
forwarding forwarding_unit(
    .opcode(ID_EX_output.control_word.opcode),
    .ID_EX_rs1(ID_EX_output.data_word.rs1),
    .ID_EX_rs2(ID_EX_output.data_word.rs2),
    .alumux1_sel(ID_EX_output.control_word.alumux1_sel),
    .alumux2_sel(alumux2_sel),
    .cmpmux2_sel(ID_EX_output.control_word.cmpmux_sel),
    .EX_MEM_rd(EX_MEM_output.data_word.rd),
    .EX_MEM_alu_out(EX_MEM_output.data_word.alu_out),
    .EX_MEM_load_regfile(EX_MEM_output.control_word.load_regfile),
    .EX_MEM_br_en(EX_MEM_output.control_word.br_en),
    .EX_MEM_regfilemux_sel(EX_MEM_output.control_word.regfilemux_sel),
    .MEM_WB_rd(MEM_WB_output.data_word.rd),
    .MEM_WB_alu_out(MEM_WB_output.data_word.alu_out),
    .MEM_WB_mdr_input(MEM_WB_input.data_word.mdr_out),
    .MEM_WB_mdr_output(MEM_WB_output.data_word.mdr_out),
    .MEM_WB_dcache_read_input(MEM_WB_input.control_word.dcache_read),
    .MEM_WB_dcache_read_output(MEM_WB_output.control_word.dcache_read),
    .MEM_WB_load_regfile(MEM_WB_output.control_word.load_regfile),
    .MEM_WB_br_en(MEM_WB_output.control_word.br_en),
    .MEM_WB_regfilemux_sel(MEM_WB_output.control_word.regfilemux_sel),
    .EX_MEM_store_forwarding(EX_MEM_store_forwarding),
    .EX_MEM_rs2_forwarding(EX_MEM_rs2_forwarding),
    .EX_MEM_alumux1_forwarding(EX_MEM_alumux1_forwarding),
    .EX_MEM_alumux2_forwarding(EX_MEM_alumux2_forwarding),
    .EX_MEM_cmpmux1_forwarding(EX_MEM_cmpmux1_forwarding),
    .EX_MEM_cmpmux2_forwarding(EX_MEM_cmpmux2_forwarding),
    .MEM_WB_alumux1_forwarding(MEM_WB_alumux1_forwarding),
    .MEM_WB_alumux2_forwarding(MEM_WB_alumux2_forwarding),
    .MEM_WB_cmpmux1_forwarding(MEM_WB_cmpmux1_forwarding),
    .MEM_WB_cmpmux2_forwarding(MEM_WB_cmpmux2_forwarding),
    .alumux1_sel_forwarding(alumux1_sel_forwarding),
    .alumux2_sel_forwarding(alumux2_sel_forwarding),
    .cmpmux1_sel_forwarding(cmpmux1_sel_forwarding),
    .cmpmux2_sel_forwarding(cmpmux2_sel_forwarding)
);

/***************************HAZARD DETECTION**************************/
hazard_detection hazard_detection_unit (
    .dcache_read(EX_MEM_output.control_word.dcache_read),
    .dcache_write(EX_MEM_output.control_word.dcache_write),
    .dcache_resp(dcache_resp),
    .icache_resp(icache_resp),
    .opcode(ID_EX_output.control_word.opcode),
    .j_en(j_en),
    .br_en(br_en),
    .src1(ID_EX_output.data_word.rs1),
    .src2(ID_EX_output.data_word.rs2),
    .dest(EX_MEM_output.data_word.rd),
    .m_ext_load(m_ext_load),
    .m_ext_resp(m_ext_resp),
    .load_pc(load_pc),
    .load_IF_ID(load_IF_ID),
    .load_ID_EX(load_ID_EX),
    .load_EX_MEM(load_EX_MEM),
    .load_MEM_WB(load_MEM_WB),
    .rst_IF_ID(rst_IF_ID),
    .rst_ID_EX(rst_ID_EX),
    .rst_EX_MEM(rst_EX_MEM),
    .rst_MEM_WB(rst_MEM_WB)
); 

/*****************************M EXTENSION****************************/
assign m_ext_load = ((ID_EX_output.control_word.opcode == op_reg) && (ID_EX_output.control_word.funct7 == 7'd1));

m_ext m_extension (
    .clk(clk), 
    .rst(rst_ID_EX), 
    .a(alumux1_out), 
    .b(alumux2_out), 
    .load(m_ext_load), 
    .funct3(ID_EX_output.control_word.funct3), 
    .m_ext_out(m_ext_out),
    .m_ext_resp(m_ext_resp)
);


/***************************branch prediction**************************/
// tournament tournament(
//     .clk(clk),
//     .rst(rst),
//     .load_EX_MEM(load_EX_MEM),
//     .opcode(EX_MEM_input.control_word.opcode),
//     .pc_IF(IF_ID_input.data_word.pc),
//     .pc_EX(EX_MEM_input.data_word.pc),
//     .br_en(EX_MEM_input.control_word.br_en),
//     .prediction(prediction),
//     .miss(miss)
// );


endmodule : datapath