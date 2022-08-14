`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath
(
    input clk,
    input rst,
    input load_mdr,//control->mdr
    input rv32i_word mem_rdata, //input port->mdr

    /* added input signals */
    input load_pc, //control->pc
    input load_ir, //control->ir
    input load_regfile, //control->regfile
    input load_mar, //control->mar
    input load_data_out, //control->mem_data_out
    input pcmux::pcmux_sel_t pcmux_sel, //control->pcmux
    input alumux::alumux1_sel_t alumux1_sel, //control->alumux1_sel
    input alumux::alumux2_sel_t alumux2_sel, //control->alumux2_sel
    input regfilemux::regfilemux_sel_t regfilemux_sel, //control->regfilemux_sel
    input marmux::marmux_sel_t marmux_sel, //control->marmux_sel
    input cmpmux::cmpmux_sel_t cmpmux_sel,  //control->cmpmux_sel
    input alu_ops aluop, //control->alu
    input branch_funct3_t cmpop, //control->cmp

    output rv32i_word mem_wdata, //mem_data_out->output port --- signal used by RVFI Monitor
    /* You will need to connect more signals to your datapath module*/

    /* added output signals */
    output rv32i_reg rs1, //ir->regfile,control
    output rv32i_reg rs2, //ir->regfile,control
    output rv32i_word mem_address, //mar->output port
    output rv32i_opcode opcode, //ir->control
    output logic [2:0] funct3, //ir->control
    output logic [6:0] funct7, //ir->control
    output logic br_en, //cmp->control,regfilemux

    output logic [1:0] shift // cp2
);

/******************* Signals Needed for RVFI Monitor *************************/
rv32i_reg rs1_s; //ir->regfile,control
rv32i_reg rs2_s; //ir->regfile,control
rv32i_reg rd; //ir->regfile
assign rs1 = rs1_s;
assign rs2 = rs2_s;
rv32i_word rs1_out; //regfile->alumux1,cmp
rv32i_word rs2_out; //regfile->cmpmux,mem_data_out
rv32i_word i_imm; //ir->alumux2,cmpmux
rv32i_word u_imm; //ir->alumux2,regfilemux
rv32i_word b_imm; //ir->alumux2
rv32i_word s_imm; //ir->alumux2
rv32i_word j_imm; //ir->!!
rv32i_word pcmux_out; //pcmux->PC
rv32i_word alumux1_out; //alumux1->alu
rv32i_word alumux2_out; //alumux2->alu
rv32i_word regfilemux_out; //regfilemux->regfile
rv32i_word marmux_out; //marmux->MAR
rv32i_word cmp_mux_out; //cmpmux->cmp
rv32i_word alu_out; //alu->regfilemux,marmux,pcmux
rv32i_word pc_out; //pc->pc_plus4,alumux1,marmux
//rv32i_word pc_plus4_out,
rv32i_word mdrreg_out; //mdr->regfilemux,ir
logic br_en_s; //cmp->control,regfilemux
assign br_en = br_en_s;

rv32i_word marreg_out;
assign mem_address = {marreg_out[31:2], 2'b0};
assign shift = marreg_out[1:0]; // changing this to alu_out causes timing error!!

rv32i_word mem_wdata_s;
always_comb begin
    unique case (funct3)
        sb: mem_wdata = (mem_wdata_s << {marreg_out[1:0], 3'b0});
        sh: mem_wdata = (mem_wdata_s << {marreg_out[1:0], 3'b0});
        sw: mem_wdata = mem_wdata_s;
        default: mem_wdata = mem_wdata_s;
    endcase 
end
/*****************************************************************************/

/***************************** Registers *************************************/
// Keep Instruction register named `IR` for RVFI Monitor
ir IR(
    .clk(clk),
    .rst(rst),
    .load(load_ir),
    .in(mdrreg_out),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),
    .i_imm(i_imm),
    .s_imm(s_imm),
    .b_imm(b_imm),
    .u_imm(u_imm),
    .j_imm(j_imm),
    .rs1(rs1_s),
    .rs2(rs2_s),
    .rd(rd)
);

register MDR(
    .clk  (clk),
    .rst (rst),
    .load (load_mdr),
    .in   (mem_rdata),
    .out  (mdrreg_out)
);

pc_register PC(
    .clk(clk),
    .rst(rst),
    .load(load_pc),
    .in(pcmux_out),
    .out(pc_out)
);

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(load_regfile),
    .in(regfilemux_out),
    .src_a(rs1_s),
    .src_b(rs2_s),
    .dest(rd),
    .reg_a(rs1_out),
    .reg_b(rs2_out)
);

register MAR(
    .clk  (clk),
    .rst (rst),
    .load (load_mar),
    .in   (marmux_out),
    .out  (marreg_out)
);

register mem_data_out(
    .clk  (clk),
    .rst (rst),
    .load (load_data_out),
    .in   (rs2_out),
    .out  (mem_wdata_s)
);
/*****************************************************************************/

/******************************* ALU and CMP *********************************/
alu ALU(
    .aluop(aluop),
    .a(alumux1_out),
    .b(alumux2_out),
    .f(alu_out)
);

cmp CMP(
    .rs1_out (rs1_out),
    .cmp_mux_out (cmp_mux_out),
    .cmpop(cmpop),
    .cmp_out(br_en_s)
);
/*****************************************************************************/

/******************************** Muxes **************************************/
always_comb begin : MUXES
    // We provide one (incomplete) example of a mux instantiated using
    // a case statement.  Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog.  In this case, we actually use
    // Offensive programming --- making simulation halt with a fatal message
    // warning when an unexpected mux select value occurs
    unique case (pcmux_sel)
        pcmux::pc_plus4: pcmux_out = pc_out + 4;
        pcmux::alu_out: pcmux_out = alu_out;
        pcmux::alu_mod2: pcmux_out = {alu_out[31:2], 2'b0};
        default: `BAD_MUX_SEL;
    endcase

    unique case (alumux1_sel)
        alumux::rs1_out: alumux1_out = rs1_out;
        alumux::pc_out: alumux1_out = pc_out;
        default: `BAD_MUX_SEL;
    endcase

    unique case (alumux2_sel)
        alumux::i_imm: alumux2_out = i_imm;
        alumux::u_imm: alumux2_out = u_imm;
        alumux::b_imm: alumux2_out = b_imm;
        alumux::s_imm: alumux2_out = s_imm;
        alumux::j_imm: alumux2_out = j_imm;
        alumux::rs2_out: alumux2_out = rs2_out;
        default: `BAD_MUX_SEL;
    endcase

    unique case (regfilemux_sel)
        regfilemux::alu_out: regfilemux_out = alu_out;
        regfilemux::br_en: regfilemux_out = {31'b0, br_en_s};
        regfilemux::u_imm: regfilemux_out = u_imm;
        regfilemux::lw: regfilemux_out = mdrreg_out;
        regfilemux::pc_plus4: regfilemux_out = pc_out + 4;
		regfilemux::lb: begin
            unique case (marreg_out[1:0])
                2'b00: regfilemux_out = {{24{mdrreg_out[7]}}, mdrreg_out[7:0]};
                2'b01: regfilemux_out = {{24{mdrreg_out[15]}}, mdrreg_out[15:8]};
                2'b10: regfilemux_out = {{24{mdrreg_out[23]}}, mdrreg_out[23:16]};
                2'b11: regfilemux_out = {{24{mdrreg_out[31]}}, mdrreg_out[31:24]};
            endcase
        end
		regfilemux::lbu: begin
            unique case (marreg_out[1:0])
                2'b00: regfilemux_out = {24'b0, mdrreg_out[7:0]};
                2'b01: regfilemux_out = {24'b0, mdrreg_out[15:8]};
                2'b10: regfilemux_out = {24'b0, mdrreg_out[23:16]};
                2'b11: regfilemux_out = {24'b0, mdrreg_out[31:24]};
            endcase
        end
		regfilemux::lh: begin
            if (marreg_out[1] == 1'b0)
                regfilemux_out = {{16{mdrreg_out[15]}}, mdrreg_out[15:0]};
            else
                regfilemux_out = {{16{mdrreg_out[31]}}, mdrreg_out[31:16]};
        end
		regfilemux::lhu: begin
            if (marreg_out[1] == 1'b0)
                regfilemux_out = {16'b0, mdrreg_out[15:0]};
            else
                regfilemux_out = {16'b0, mdrreg_out[31:16]};
        end
        default: `BAD_MUX_SEL;
    endcase

    unique case (marmux_sel)
        marmux::pc_out: marmux_out = pc_out;
        marmux::alu_out: marmux_out = alu_out;
        default: `BAD_MUX_SEL;
    endcase

    unique case (cmpmux_sel)
        cmpmux::rs2_out: cmp_mux_out = rs2_out;
        cmpmux::i_imm: cmp_mux_out = i_imm;
        default: `BAD_MUX_SEL;
    endcase

end
/*****************************************************************************/
endmodule : datapath
