import rv32i_types::*;

module gbht(
    input clk,
    input rst,
    input logic load_EX_MEM,    // EX
    input rv32i_opcode opcode,  // EX
    input rv32i_word pc,        // EX        
    input logic br_en,          // EX
    output logic prediction,    // IF
    output logic miss           // EX
);

// 00 - Strongly Not Take, 01 - Not Take, 10 - Take, 11 - Strongly Take
logic [7:0] branch_hist_reg, next_branch_hist_reg;
logic [1:0] pattern_hist_table[256]; 
logic [1:0] state;

assign next_branch_hist_reg = {branch_hist_reg[6:0], br_en};
assign state = pattern_hist_table[branch_hist_reg];
assign prediction = state[1];

always_ff @(posedge clk) begin 
    if (rst) begin
        branch_hist_reg <= 8'b0;
        for (int i = 0; i < 256; i++)
            pattern_hist_table[i] <= 2'b01;
    end
    else if ((opcode == op_br) && load_EX_MEM) begin
        miss <= (state[1] != br_en);
        unique case (state)
            2'b00: pattern_hist_table[branch_hist_reg] <= (br_en) ? 2'b01 : 2'b00;
            2'b01: pattern_hist_table[branch_hist_reg] <= (br_en) ? 2'b10 : 2'b00;
            2'b10: pattern_hist_table[branch_hist_reg] <= (br_en) ? 2'b11 : 2'b01;    
            2'b11: pattern_hist_table[branch_hist_reg] <= (br_en) ? 2'b11 : 2'b10;
            default ; 
        endcase
        branch_hist_reg <= next_branch_hist_reg;
    end
end

endmodule : gbht

