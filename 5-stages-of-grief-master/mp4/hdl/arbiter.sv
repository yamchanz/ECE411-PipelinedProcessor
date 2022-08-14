import rv32i_types::*;

module arbiter (
    input clk, 
    input rst,

    // instr pmem inputs
    input rv32i_word instr_mem_addr,
    input logic instr_mem_read, 

    // data pmem inputs
    input rv32i_word data_mem_addr,
    input logic data_mem_read, 
    input logic data_mem_write,
    input logic [255:0] data_mem_write_data, 

    // int pmem outputs
    output logic [255:0] instr_mem_read_data, 
    output logic instr_mem_resp,

    // data pmem outputs
    output logic [255:0] data_mem_read_data, 
    output logic data_mem_resp,

    // from/to cacheline adaptor
    input logic [63:0] mem_read_data, 
    input logic mem_resp,

    output logic [63:0] mem_write_data,
    output logic mem_read,
    output logic mem_write,
    output rv32i_word mem_addr
);

logic [255:0] cacheline_line_inp,cacheline_line_out;
rv32i_word cacheline_addr;
logic cacheline_read, cacheline_write, cacheline_response;

enum int unsigned {
    idle_state, instr_state, data_state
} state, change_state;
    
always_comb begin
    /*initial values for cacheline_adaptor*/
    cacheline_line_inp = data_mem_write_data;
    instr_mem_read_data = cacheline_line_out;
    data_mem_read_data = cacheline_line_out;
    cacheline_read = 1'b0;
    cacheline_write = 1'b0;
    cacheline_addr = 32'd0;
    instr_mem_resp = 1'b0;
    data_mem_resp = 1'b0;
    case(state)
        idle_state: begin 
            if(instr_mem_read || data_mem_read) 
                cacheline_read = 1'b1;
            else if(data_mem_write) 
                cacheline_write = 1'b1;
            if(instr_mem_read) 
                cacheline_addr = instr_mem_addr;
            else 
                cacheline_addr = data_mem_addr;
        end
        data_state: begin
            if(cacheline_response) begin
                data_mem_resp = 1'b1;
                if (instr_mem_read) begin 
                    cacheline_addr = instr_mem_addr; 
                    cacheline_read = 1'b1; 
                end 
            end 
            else begin 
                cacheline_addr = data_mem_addr;
                if(data_mem_read)  
                    cacheline_read = 1'b1;
                else  
                    cacheline_write = 1'b1; 
            end 
        end
        instr_state: begin 
            if(cacheline_response) begin
                instr_mem_resp = 1'b1;
                if(data_mem_read || data_mem_write) begin 
                    cacheline_addr = data_mem_addr; 
                    if (data_mem_read)
                        cacheline_read = 1'b1;
                    else
                        cacheline_write = 1'b1; 
                end 
            end 
            else begin 
                cacheline_addr = instr_mem_addr;
                cacheline_read = 1'b1;
            end 
        end
        default:;
    endcase
end 

/*Update States (state diagram implementation)*/
always_comb begin
    change_state = state;
    case(state)
        idle_state: begin
            if(instr_mem_read) 
                change_state = instr_state;
            else if (data_mem_write || data_mem_read) 
                change_state = data_state;
            else 
                change_state = idle_state;
        end
        instr_state: begin
            if(!cacheline_response) 
                change_state = instr_state;
            else if (data_mem_read || data_mem_write) 
                change_state = data_state;
            else 
                change_state = idle_state;
        end
        data_state: begin
            if(!cacheline_response)  
                change_state = data_state;
            else if (instr_mem_read) 
                change_state = instr_state;
            else  
                change_state = idle_state;
        end
        default: change_state = idle_state;
    endcase
end

always_ff @(posedge clk) begin
    if(rst)
        state <= idle_state;
    else
        state <= change_state;
end

cacheline_adaptor cacheline_adaptor (
    .clk(clk),
    .reset_n(~rst),
    .line_i(cacheline_line_inp),
    .line_o(cacheline_line_out),
    .address_i(cacheline_addr),
    .read_i(cacheline_read),
    .write_i(cacheline_write),
    .resp_o(cacheline_response),
    .burst_i(mem_read_data),
    .burst_o(mem_write_data),
    .address_o(mem_addr),
    .read_o(mem_read),
    .write_o(mem_write),
    .resp_i(mem_resp)
);

endmodule : arbiter 