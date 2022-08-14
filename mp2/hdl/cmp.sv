//`define BAD_CMP $fatal("%0t %s %0d: Illegal cmp select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module cmp
(
    input rv32i_word rs1_out, 
    input rv32i_word cmp_mux_out,
    input branch_funct3_t cmpop,
    output logic cmp_out
);

always_comb begin : cmp_logic
    unique case (cmpop)
        beq: cmp_out = (rs1_out == cmp_mux_out);
        bne: cmp_out = (rs1_out != cmp_mux_out);
        blt: cmp_out = ($signed(rs1_out) < $signed(cmp_mux_out));
        bge: cmp_out = ($signed(rs1_out) >= $signed(cmp_mux_out));
        bltu: cmp_out = (rs1_out < cmp_mux_out);
        bgeu: cmp_out = (rs1_out >= cmp_mux_out);
        default: cmp_out = 1'b0;
    endcase
end

endmodule : cmp