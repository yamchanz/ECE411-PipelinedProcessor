import rv32i_types::*;

module forwarding (
    // ID_EX input
    input rv32i_opcode opcode,
    input rv32i_reg ID_EX_rs1,
    input rv32i_reg ID_EX_rs2,
    input logic alumux1_sel,
    input logic alumux2_sel,
    input logic cmpmux2_sel,
    // EX_MEM input
    input rv32i_reg EX_MEM_rd,
    input rv32i_word EX_MEM_alu_out,
    input logic EX_MEM_load_regfile,
    input logic EX_MEM_br_en,
    input regfilemux::regfilemux_sel_t EX_MEM_regfilemux_sel,
    // MEM_WB input
    input rv32i_reg MEM_WB_rd,
    input rv32i_word MEM_WB_alu_out,
    input rv32i_word MEM_WB_mdr_input,
    input rv32i_word MEM_WB_mdr_output,
    input logic MEM_WB_dcache_read_input,
    input logic MEM_WB_dcache_read_output,
    input logic MEM_WB_load_regfile,
    input logic MEM_WB_br_en,
    input regfilemux::regfilemux_sel_t MEM_WB_regfilemux_sel,
    // EX_MEM forwarding output
    output logic EX_MEM_store_forwarding,
    output rv32i_word EX_MEM_rs2_forwarding,  
    output rv32i_word EX_MEM_alumux1_forwarding,
    output rv32i_word EX_MEM_alumux2_forwarding,
    output rv32i_word EX_MEM_cmpmux1_forwarding,
    output rv32i_word EX_MEM_cmpmux2_forwarding,
    // MEM_WB forwarding output
    output rv32i_word MEM_WB_alumux1_forwarding,
    output rv32i_word MEM_WB_alumux2_forwarding,
    output rv32i_word MEM_WB_cmpmux1_forwarding,
    output rv32i_word MEM_WB_cmpmux2_forwarding,
    // ALU/CMP MUX Forwarding condition
    output logic [1:0] alumux1_sel_forwarding,
    output logic [1:0] alumux2_sel_forwarding,
    output logic [1:0] cmpmux1_sel_forwarding,
    output logic [1:0] cmpmux2_sel_forwarding
);

logic [1:0] forwarding_condition;

assign forwarding_condition = {EX_MEM_load_regfile, MEM_WB_load_regfile};

function void set_alu_defaults();
    EX_MEM_alumux1_forwarding = 32'd0;
    EX_MEM_alumux2_forwarding = 32'd0;
    MEM_WB_alumux1_forwarding = 32'd0;
    MEM_WB_alumux2_forwarding = 32'd0;
    alumux1_sel_forwarding    = 2'd0;
    alumux2_sel_forwarding    = 2'd0;
endfunction

function void set_cmp_defaults();
    EX_MEM_cmpmux1_forwarding = 32'd0;
    EX_MEM_cmpmux2_forwarding = 32'd0;
    MEM_WB_cmpmux1_forwarding = 32'd0;
    MEM_WB_cmpmux2_forwarding = 32'd0;
    cmpmux1_sel_forwarding    = 2'd0;
    cmpmux2_sel_forwarding    = 2'd0;
endfunction

function void set_rs2_defaults();
    EX_MEM_store_forwarding = 1'b0; 
    EX_MEM_rs2_forwarding   = 32'd0;
endfunction

// ALU forwarding logic
always_comb begin
    set_alu_defaults();
    unique case(forwarding_condition)
        2'b00:;
        2'b01: begin
            if((MEM_WB_rd == ID_EX_rs1) && (!alumux1_sel)) begin
                alumux1_sel_forwarding = 2'b11;
                if(ID_EX_rs1 == 5'd0) 
                    MEM_WB_alumux1_forwarding = 32'd0;
                else if(MEM_WB_regfilemux_sel == regfilemux::br_en) 
                    MEM_WB_alumux1_forwarding = MEM_WB_br_en;
                else 
                    MEM_WB_alumux1_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
            end
            if((MEM_WB_rd == ID_EX_rs2) && alumux2_sel) begin
                alumux2_sel_forwarding = 2'b11;
                if(ID_EX_rs2 == 5'd0) 
                    MEM_WB_alumux2_forwarding = 32'd0;
                else if(MEM_WB_regfilemux_sel == regfilemux::br_en) 
                    MEM_WB_alumux2_forwarding = MEM_WB_br_en;
                else 
                    MEM_WB_alumux2_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
            end
        end
        2'b10: begin
            if((EX_MEM_rd == ID_EX_rs1) && (!alumux1_sel)) begin
                alumux1_sel_forwarding = 2'b01;
                if(ID_EX_rs1 == 5'd0)
                    EX_MEM_alumux1_forwarding = 32'd0;
                else if(EX_MEM_regfilemux_sel == regfilemux::br_en) 
                    EX_MEM_alumux1_forwarding = EX_MEM_br_en;
                else 
                    EX_MEM_alumux1_forwarding = MEM_WB_dcache_read_input? MEM_WB_mdr_input : EX_MEM_alu_out;
            end
            if((EX_MEM_rd == ID_EX_rs2) && alumux2_sel) begin
                alumux2_sel_forwarding = 2'b01;
                if(ID_EX_rs2 == 5'd0)
                    EX_MEM_alumux2_forwarding = 32'd0;
                else if(EX_MEM_regfilemux_sel == regfilemux::br_en)
                    EX_MEM_alumux2_forwarding = EX_MEM_br_en;
                else 
                    EX_MEM_alumux2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
            end
        end 
        2'b11: begin
            if(MEM_WB_rd == EX_MEM_rd) begin
                if((EX_MEM_rd == ID_EX_rs1) && (!alumux1_sel)) begin
                    alumux1_sel_forwarding = 2'b01;
                    if(ID_EX_rs1 == 5'd0)
                        EX_MEM_alumux1_forwarding = 32'd0;
                    else if(EX_MEM_regfilemux_sel == regfilemux::br_en)
                        EX_MEM_alumux1_forwarding = EX_MEM_br_en;
                    else
                        EX_MEM_alumux1_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
                end
                if((EX_MEM_rd == ID_EX_rs2) && alumux2_sel) begin
                    alumux2_sel_forwarding = 2'b01;
                    if(ID_EX_rs2 == 5'd0)
                        EX_MEM_alumux2_forwarding = 32'd0;
                    else if(EX_MEM_regfilemux_sel == regfilemux::br_en) 
                        EX_MEM_alumux2_forwarding = EX_MEM_br_en;
                    else 
                        EX_MEM_alumux2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
                end
            end
            else begin
                if((EX_MEM_rd == ID_EX_rs1) && (!alumux1_sel)) begin
                    alumux1_sel_forwarding = 2'b01;
                    if(ID_EX_rs1 == 5'd0)
                        EX_MEM_alumux1_forwarding = 32'd0;
                    else if(EX_MEM_regfilemux_sel == regfilemux::br_en)
                        EX_MEM_alumux1_forwarding = EX_MEM_br_en;
                    else 
                        EX_MEM_alumux1_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;   
                end
                else if((MEM_WB_rd == ID_EX_rs1) && (!alumux1_sel)) begin
                    alumux1_sel_forwarding = 2'b11;
                    if(ID_EX_rs1 == 5'd0) 
                        MEM_WB_alumux1_forwarding = 32'd0;
                    else if(MEM_WB_regfilemux_sel == regfilemux::br_en)
                        MEM_WB_alumux1_forwarding = MEM_WB_br_en;
                    else 
                        MEM_WB_alumux1_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
                end
                if((EX_MEM_rd == ID_EX_rs2) && alumux2_sel) begin
                    alumux2_sel_forwarding = 2'b01;
                    if(ID_EX_rs2 == 5'd0) 
                        EX_MEM_alumux2_forwarding = 32'd0;
                    else if(EX_MEM_regfilemux_sel == regfilemux::br_en)
                        EX_MEM_alumux2_forwarding = EX_MEM_br_en;
                    else 
                        EX_MEM_alumux2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
                end               
                else if((MEM_WB_rd == ID_EX_rs2) && alumux2_sel) begin
                    alumux2_sel_forwarding = 2'b11;
                    if(ID_EX_rs2 == 5'd0) 
                        MEM_WB_alumux2_forwarding = 32'd0;
                    else if(MEM_WB_regfilemux_sel == regfilemux::br_en)
                        MEM_WB_alumux2_forwarding = MEM_WB_br_en;
                    else 
                        MEM_WB_alumux2_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
                end
            end
        end
    endcase
end

// CMP forwarding logic
always_comb begin
    set_cmp_defaults();
    if(EX_MEM_rd == ID_EX_rs1) begin
        cmpmux1_sel_forwarding = 2'b01;
        if(ID_EX_rs1 == 5'd0)
            EX_MEM_cmpmux1_forwarding = 32'd0;
        else if(EX_MEM_regfilemux_sel == regfilemux::br_en)
            EX_MEM_cmpmux1_forwarding = EX_MEM_br_en;
        else 
            EX_MEM_cmpmux1_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
    end
    else if(MEM_WB_rd == ID_EX_rs1) begin
        cmpmux1_sel_forwarding = 2'b11;
        if(ID_EX_rs1 == 5'd0)
            MEM_WB_cmpmux1_forwarding = 32'd0;
        else if(MEM_WB_regfilemux_sel == regfilemux::br_en) 
            MEM_WB_cmpmux1_forwarding = MEM_WB_br_en;
        else 
            MEM_WB_cmpmux1_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out; 
    end

    if(EX_MEM_rd == ID_EX_rs2 && (!cmpmux2_sel)) begin
        cmpmux2_sel_forwarding = 2'b01;
        if(ID_EX_rs2 == 5'd0)
            EX_MEM_cmpmux2_forwarding = 32'd0;
        else if(EX_MEM_regfilemux_sel == regfilemux::br_en)
            EX_MEM_cmpmux2_forwarding = EX_MEM_br_en;
        else 
            EX_MEM_cmpmux2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
    end
    else if(MEM_WB_rd == ID_EX_rs2 && (!cmpmux2_sel)) begin
        cmpmux2_sel_forwarding = 2'b11;
        if(ID_EX_rs2 == 5'd0)
            MEM_WB_cmpmux2_forwarding = 32'd0; 
        else if(MEM_WB_regfilemux_sel == regfilemux::br_en) 
            MEM_WB_cmpmux2_forwarding = MEM_WB_br_en;
        else  
            MEM_WB_cmpmux2_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
    end
end

// rs2 forwarding logic
always_comb begin
    set_rs2_defaults();
    if(opcode == op_store) begin
        unique case(forwarding_condition)
            2'b00:;
            2'b01: begin
                if(MEM_WB_rd == ID_EX_rs2) begin
                    EX_MEM_store_forwarding = 1'b1;
                    EX_MEM_rs2_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
                end
            end
            2'b10: begin
                if(EX_MEM_rd == ID_EX_rs2) begin
                    EX_MEM_store_forwarding = 1'b1;
                    EX_MEM_rs2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
                end
            end
            2'b11: begin
                if(MEM_WB_rd == EX_MEM_rd) begin
                    if(EX_MEM_rd == ID_EX_rs2) begin
                        EX_MEM_store_forwarding = 1'b1;
                        EX_MEM_rs2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;
                    end
                end
                else if(MEM_WB_rd == ID_EX_rs2) begin
                    EX_MEM_store_forwarding = 1'b1;
                    EX_MEM_rs2_forwarding = MEM_WB_dcache_read_output ? MEM_WB_mdr_output : MEM_WB_alu_out;
                end
                else if(EX_MEM_rd == ID_EX_rs2) begin
                    EX_MEM_store_forwarding = 1'b1;
                    EX_MEM_rs2_forwarding = MEM_WB_dcache_read_input ? MEM_WB_mdr_input : EX_MEM_alu_out;                      
                end
            end
        endcase
    end
end

endmodule : forwarding