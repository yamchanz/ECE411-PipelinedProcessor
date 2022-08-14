import rv32i_types::*;

module control_rom
(
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    output rv32i_control_word ctrl
);

branch_funct3_t branch_funct3;
load_funct3_t load_funct3;
arith_funct3_t arith_funct3;

assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
    ctrl.load_regfile = 1'b1; 
    ctrl.regfilemux_sel = sel;
endfunction

function void setALU(alumux::alumux1_sel_t sel1, logic setop = 1'b0, alu_ops op = alu_add);
    if (setop) begin 
        ctrl.aluop = op;
        ctrl.alumux1_sel = sel1; 
    end 
endfunction

function automatic void setCMP(cmpmux::cmpmux_sel_t sel, logic setop = 1'b0, branch_funct3_t op = beq);
    if (setop) begin 
        ctrl.cmpop = op; 
        ctrl.cmpmux_sel = sel; 
    end 
endfunction

function void set_defaults();
    ctrl.opcode = opcode; 
    ctrl.aluop = alu_add; 
    ctrl.regfilemux_sel = regfilemux::alu_out; 
    ctrl.load_regfile = 1'b0;
    ctrl.alumux1_sel = alumux::rs1_out; 
    ctrl.cmpmux_sel = cmpmux::rs2_out; 
    ctrl.cmpop = beq; 
    ctrl.dcache_read = 1'b0;
    ctrl.dcache_write = 1'b0; 
    ctrl.dcache_byte_enable = 4'b1111; 
    ctrl.funct3 = funct3; 
    ctrl.funct7 = funct7;
    ctrl.br_en = 1'b0; 
endfunction


always_comb begin
    /* Default assignments */
    set_defaults();

    /* Assign control signals based on opcode */
    case(opcode)
        op_lui: loadRegfile(regfilemux::u_imm);
        op_auipc: begin
            loadRegfile(regfilemux::alu_out);  
            setALU(alumux::pc_out, 1'b1, alu_add);     
        end
        op_jal: begin 
            loadRegfile(regfilemux::pc_plus4);
            setALU(alumux::pc_out, 1'b1, alu_add);
        end 
        op_jalr: begin 
            loadRegfile(regfilemux::pc_plus4);
            setALU(alumux::rs1_out, 1'b1, alu_add);
        end 
        op_br: begin 
            setALU(alumux::pc_out, 1'b1, alu_add); 
            setCMP(cmpmux::rs2_out, 1'b1, branch_funct3);
        end 
        op_load: begin 
            ctrl.dcache_read = 1'b1; 
            setALU(alumux::rs1_out, 1'b1, alu_add);
            case(load_funct3)
                lb: loadRegfile(regfilemux::lb);
                lh: loadRegfile(regfilemux::lh);
                lw: loadRegfile(regfilemux::lw);
                lbu: loadRegfile(regfilemux::lbu);
                lhu: loadRegfile(regfilemux::lhu);
                default:;
            endcase
        end 
        op_store: begin 
            ctrl.dcache_write = 1'b1; 
            setALU(alumux::rs1_out, 1'b1, alu_add);
        end 
        op_imm: begin 
            case(arith_funct3)
                slt: begin 
                    setCMP(cmpmux::i_imm, 1'b1, blt);
                    loadRegfile(regfilemux::br_en);
                end 
                sltu: begin 
                    setCMP(cmpmux::i_imm, 1'b1, bltu);   
                    loadRegfile(regfilemux::br_en);
                end 
                sr: begin 
                    loadRegfile(regfilemux::alu_out);
                    if(funct7[5])
                        setALU(alumux::rs1_out, 1'b1, alu_sra);
                    else
                        setALU(alumux::rs1_out, 1'b1, alu_srl);
                end
                default: begin 
                    loadRegfile(regfilemux::alu_out);
                    setALU(alumux::rs1_out, 1'b1, alu_ops'(arith_funct3));
                end 
            endcase 
        end 
        op_reg: begin
            if(funct7 == 7'd1) 
                loadRegfile(regfilemux::alu_out);
            else begin
                case(arith_funct3)
                    slt: begin 
                        setCMP(cmpmux::rs2_out, 1'b1, blt);
                        loadRegfile(regfilemux::br_en);
                    end 
                    sltu: begin 
                        setCMP(cmpmux::rs2_out, 1'b1, bltu);
                        loadRegfile(regfilemux::br_en);                    
                    end 
                    sr: begin 
                        loadRegfile(regfilemux::alu_out);
                        if(funct7[5])
                            setALU(alumux::rs1_out, 1'b1, alu_sra);
                        else
                            setALU(alumux::rs1_out, 1'b1, alu_srl);                    
                    end 
                    add: begin
                        loadRegfile(regfilemux::alu_out); 
                        if(funct7[5])
                            setALU(alumux::rs1_out, 1'b1, alu_sub);
                        else
                            setALU(alumux::rs1_out, 1'b1, alu_add);
                    end 
                    default: begin 
                        loadRegfile(regfilemux::alu_out);
                        setALU(alumux::rs1_out, 1'b1, alu_ops'(arith_funct3));
                    end    
                endcase 
            end
        end
        default: set_defaults();
    endcase
end
endmodule : control_rom