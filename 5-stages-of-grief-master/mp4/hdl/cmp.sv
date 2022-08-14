import rv32i_types::*;

module cmp
(
    input rv32i_word cmp_mux1_out, 
    input rv32i_word cmp_mux2_out,
    input branch_funct3_t cmpop,
    output logic cmp_out
);

always_comb begin : cmp_logic
    unique case (cmpop)
        beq: cmp_out = (cmp_mux1_out == cmp_mux2_out);
        bne: cmp_out = (cmp_mux1_out != cmp_mux2_out);
        blt: cmp_out = ($signed(cmp_mux1_out) < $signed(cmp_mux2_out));
        bge: cmp_out = ($signed(cmp_mux1_out) >= $signed(cmp_mux2_out));
        bltu: cmp_out = (cmp_mux1_out < cmp_mux2_out);
        bgeu: cmp_out = (cmp_mux1_out >= cmp_mux2_out);
    endcase
end

endmodule : cmp