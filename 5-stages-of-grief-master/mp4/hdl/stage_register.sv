import rv32i_types::*; 

module stage_register (
    input clk, 
    input rst, 
    input load, 
    input rv32i_stage_reg input_word,
    output rv32i_stage_reg output_word
);

rv32i_stage_reg data;

always_ff @(posedge clk) begin
    if (rst) begin
        data.control_word.opcode <= rv32i_opcode'(7'd0); 
        data.control_word.aluop <= alu_add; 
        data.control_word.regfilemux_sel <= regfilemux::alu_out; 
        data.control_word.load_regfile <= 1'b0;
        data.control_word.alumux1_sel <= alumux::rs1_out; 
        data.control_word.cmpmux_sel <= cmpmux::rs2_out; 
        data.control_word.cmpop <= beq; 
        data.control_word.dcache_read <= 1'b0;
        data.control_word.dcache_write <= 1'b0; 
        data.control_word.dcache_byte_enable <= 4'b1111; 
        data.control_word.funct3 <= 3'd0; 
        data.control_word.funct7 <= 7'd0; 
        data.control_word.br_en <= 1'b0; 
        data.data_word.pc <= 32'd0; 
        data.data_word.imm <= 32'd0;
        data.data_word.rs1 <= 5'd0; 
        data.data_word.rs2 <= 5'd0; 
        data.data_word.rd <= 5'd0; 
        data.data_word.rs1_out <= 32'd0; 
        data.data_word.rs2_out <= 32'd0;
        data.data_word.alu_out <= 32'd0; 
        data.data_word.mdr_out <= 32'd0;
    end
    else if (load)
        data <= input_word;
    else 
        data <= data; 
end

always_comb begin
    output_word = data; 
end

endmodule : stage_register