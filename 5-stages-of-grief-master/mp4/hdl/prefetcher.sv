import rv32i_types::*; 

module prefetcher (
    input clk, 
    input rst, 
    // I/O between prefetcher and icache
    input rv32i_word icache_pref_address, 
    input logic icache_pref_read,
    output logic [255:0] pref_icache_rdata, 
    output logic pref_icache_resp, 
    // I/O between prefetcher and arbiter
    input logic [255:0] arb_pref_rdata, 
    input logic arb_pref_resp,
    output rv32i_word pref_arb_address,
    output logic pref_arb_read
);

rv32i_word pref_addr_in;
rv32i_word pref_addr_out;
logic [255:0] pref_data_in;
logic [255:0] pref_data_out; 
logic prefetch_done; 

enum int unsigned {
    idle, 
    miss, 
    prefetch
} state, next_state;

function void set_defaults();
    pref_icache_rdata = 256'd0; 
    pref_icache_resp = 1'b0; 
    pref_arb_address = 32'd0; 
    pref_arb_read = 1'b0; 
    pref_addr_in = pref_addr_out; 
    pref_data_in = pref_data_out; 
endfunction

always_comb begin : state_actions 
    set_defaults();
    case(state)
        idle: begin 
            if (icache_pref_read) begin 
                if (prefetch_done && (icache_pref_address == pref_addr_out)) begin 
                    pref_icache_rdata = pref_data_out; 
                    pref_icache_resp = 1'b1; 
                end
                else 
                    pref_addr_in = icache_pref_address + 32'd4;
            end 
        end 
        miss: begin 
            pref_arb_address = icache_pref_address; 
            pref_arb_read = 1'b1; 
            if (arb_pref_resp) begin 
                pref_icache_rdata = arb_pref_rdata;
                pref_icache_resp = 1'b1; 
            end 
        end
        prefetch: begin 
            pref_arb_address = pref_addr_out; 
            pref_arb_read = 1'b1; 
            if (arb_pref_resp)  
                pref_data_in = arb_pref_rdata; 
        end  
        default:;
    endcase 
end

always_comb begin : next_state_logic 
    case(state)
        idle: begin 
            if (icache_pref_read) begin 
                if ((icache_pref_address!=pref_addr_out) || (!prefetch_done))
                    next_state = miss; 
                else
                    next_state = idle; 
            end 
            else
                next_state = idle; 
        end 
        miss: begin 
            if (arb_pref_resp)
                next_state = prefetch; 
            else
                next_state = miss;
        end 
        prefetch: begin 
            if (arb_pref_resp)
                next_state = idle; 
            else
                next_state = prefetch; 
        end 
        default: next_state = idle; 
    endcase 
end

always_ff @(posedge clk) begin 
    if (rst) begin
        pref_addr_out <= 32'd0; 
        pref_data_out <= 256'd0; 
        state <= idle; 
    end
    else begin
        pref_addr_out <= pref_addr_in; 
        pref_data_out <= pref_data_in; 
        state <= next_state; 
    end
end

always_ff @(posedge clk) begin 
    if (rst)
        prefetch_done <= 1'b0; 
    else if (state==miss)
        prefetch_done <= 1'b0; 
    else if ((state==prefetch) && arb_pref_resp)
        prefetch_done <= 1'b1; 
end 

endmodule : prefetcher 
