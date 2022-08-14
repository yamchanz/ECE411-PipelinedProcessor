import rv32i_types::*;

module lbht(
    input clk,
    input rst,
    input logic load_EX_MEM,    // EX
    input rv32i_opcode opcode,  // EX
    input rv32i_word pc_IF,     // IF 
    input rv32i_word pc_EX,     // EX
    input logic br_en,          // EX
    output logic prediction,    // IF
    output logic miss           // EX
);

// 00 - Strongly Not Take, 01 - Not Take, 10 - Take, 11 - Strongly Take
logic [3:0] branch_hist_table[32];
logic [3:0] branch_hist_reg, next_branch_hist_reg;
logic [1:0] pattern_hist_table[32][16]; // lookup: [pc_offset][branch_hist_reg]
logic [1:0] state;
logic [4:0] pc_offset;

assign pc_offset = pc_EX[6:2];
assign branch_hist_reg = branch_hist_table[pc_offset];
assign next_branch_hist_reg = {branch_hist_table[pc_offset][2:0], br_en};
assign state = pattern_hist_table[pc_offset][branch_hist_reg];
assign prediction = pattern_hist_table[pc_IF[6:2]][branch_hist_table[pc_IF[6:2]]][1];

always_ff @(posedge clk) begin 
    if (rst) begin
        for (int i = 0; i < 32; i++) begin
            branch_hist_table[i] <= 4'b0;
            for (int j = 0; j < 16; j++)
                pattern_hist_table[i][j] <= 2'b01;
        end
    end
    else if ((opcode == op_br) && load_EX_MEM) begin
        miss <= (state[1] != br_en);
        unique case (state)
            2'b00: pattern_hist_table[pc_offset][branch_hist_reg] <= (br_en) ? 2'b01 : 2'b00;
            2'b01: pattern_hist_table[pc_offset][branch_hist_reg] <= (br_en) ? 2'b10 : 2'b00;
            2'b10: pattern_hist_table[pc_offset][branch_hist_reg] <= (br_en) ? 2'b11 : 2'b01;    
            2'b11: pattern_hist_table[pc_offset][branch_hist_reg] <= (br_en) ? 2'b11 : 2'b10;
            default ; 
        endcase
        branch_hist_table[pc_offset] <= next_branch_hist_reg;
    end
end

endmodule : lbht

