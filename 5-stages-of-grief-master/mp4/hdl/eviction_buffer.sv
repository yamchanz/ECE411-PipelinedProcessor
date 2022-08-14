import rv32i_types::*; 

module eviction_buffer (
    input clk, 
    input rst, 
    // I/O between data cache and eviction buffer
    input rv32i_word dcache_evb_address,
    input logic dcache_evb_write, 
    input logic dcache_evb_read, 
    input logic [255:0] dcache_evb_wdata,
    output logic [255:0] evb_dcache_rdata, 
    output logic evb_dcache_resp, 
    // I/O between arbiter and eviction buffer
    input logic [255:0] arb_evb_rdata, 
    input logic arb_evb_resp, 
    output logic evb_arb_write, 
    output logic evb_arb_read, 
    output rv32i_word evb_arb_address,
    output logic [255:0] evb_arb_wdata
);

rv32i_word buf_addr_in;
rv32i_word buf_addr_out;
logic [255:0] buf_data_in;
logic [255:0] buf_data_out; 
logic writeback; 

enum int unsigned {
    idle, 
    read, 
    write_back
} state, next_state; 

function void set_defaults();
    evb_dcache_rdata = 256'd0; 
    evb_dcache_resp = 1'b0; 
    evb_arb_write = 1'b0;
    evb_arb_read = 1'b0; 
    evb_arb_address = 32'd0; 
    evb_arb_wdata = 256'd0; 
    buf_addr_in = buf_addr_out;
    buf_data_in = buf_data_out; 
endfunction

always_comb begin : state_actions 
    set_defaults();
    case(state)
        idle: begin 
            if (dcache_evb_write) begin 
                evb_dcache_resp = 1'b1; 
                buf_addr_in = dcache_evb_address; 
                buf_data_in = dcache_evb_wdata; 
            end 
        end
        read: begin 
            evb_dcache_rdata = arb_evb_rdata; 
            evb_dcache_resp = arb_evb_resp; 
            evb_arb_address = dcache_evb_address; 
            evb_arb_read = 1'b1; 
        end  
        write_back: begin 
            evb_arb_wdata = buf_data_out; 
            evb_arb_address = buf_addr_out;
            evb_arb_write = 1'b1; 
        end 
        default:;
    endcase 
end 

always_comb begin : next_state_logic 
    case(state)
        idle: begin 
            if (dcache_evb_read)
                next_state = read; 
            else
                next_state = idle; 
        end 
        read: begin 
            if (arb_evb_resp) begin 
                if (writeback)
                    next_state = write_back; 
                else
                    next_state = idle; 
            end 
            else
                next_state = read; 
        end 
        write_back: begin 
            if (arb_evb_resp)
                next_state = idle; 
            else
                next_state = write_back; 
        end 
        default: next_state = idle; 
    endcase 
end 

always_ff @(posedge clk) begin 
    if (rst) begin
        buf_addr_out <= 32'd0; 
        buf_data_out <= 256'd0;
        state <= idle; 
    end
    else begin
        buf_addr_out <= buf_addr_in; 
        buf_data_out <= buf_data_in; 
        state <= next_state;
    end 
end

always_ff @(posedge clk) begin
    if (rst)
        writeback <= 1'b0; 
    else if(state==write_back)
        writeback <= 1'b0; 
    else if ((state==idle) && dcache_evb_write)
        writeback <= 1'b1; 
end

endmodule : eviction_buffer