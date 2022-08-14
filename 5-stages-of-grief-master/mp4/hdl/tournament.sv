import rv32i_types::*;

module tournament(
    input clk,
    input rst,
    input logic load_EX_MEM,    // EX
    input rv32i_opcode opcode,  // EX
    //input rv32i_opcode opcode_EX, 
    input rv32i_word pc_IF,     // IF 
    input rv32i_word pc_EX,     // EX
    input logic br_en,          // EX
    output logic prediction,    // IF
    output logic miss           // EX
);

// 00 - Strongly Take GBHT, 01 - Take GBHT, 10 - Take LBHT, 11 - Strongly Take LBHT
logic glob_prediction, glob_miss, loc_prediction, loc_miss;
logic [1:0] state_table[32]; // lookup [pc_offset]
logic [1:0] state;
logic [4:0] pc_offset;

assign pc_offset = pc_EX[6:2];
assign state = state_table[pc_offset];
assign prediction = (state_table[pc_IF[6:2]][1]) ? loc_prediction : glob_prediction;

gbht GBHT(
    .clk(clk),
    .rst(rst),
    .load_EX_MEM(load_EX_MEM),
    .opcode(opcode),
    .pc(pc_EX),
    .br_en(br_en),
    .prediction(glob_prediction),
    .miss(glob_miss)
);

lbht LBHT(
    .clk(clk),
    .rst(rst),
    .load_EX_MEM(load_EX_MEM),
    .opcode(opcode),
    .pc_IF(pc_IF),
    .pc_EX(pc_EX),
    .br_en(br_en),
    .prediction(loc_prediction),
    .miss(loc_miss)
);

always_ff @(posedge clk) begin 
    if (rst) begin
        for (int i = 0; i < 32; i++) 
            state_table[i] <= 2'b01;
    end
    else if ((opcode == op_br) && load_EX_MEM) begin //delay here??
        miss <= (state[1]) ? loc_miss : glob_miss; 
        unique case (state)
            2'b00: state_table[pc_offset] <= (!glob_miss && loc_miss) ? 2'b00 : 2'b01;//take GBHT
            2'b01: state_table[pc_offset] <= (!glob_miss && loc_miss) ? 2'b00 : 2'b10;
            2'b10: state_table[pc_offset] <= (glob_miss && !loc_miss) ? 2'b11 : 2'b01;    
            2'b11: state_table[pc_offset] <= (glob_miss && !loc_miss) ? 2'b11 : 2'b10;//take LBHT
            default ; 
        endcase
    end
end

endmodule : tournament
