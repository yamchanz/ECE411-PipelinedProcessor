/* MODIFY. The cache controller. It is a state machine
that controls the behavior of the cache. */

module cache_control (
    input clk,
    input rst,

    // CPU -> cache
    input logic [31:0] mem_address,
    input logic mem_read,
    input logic mem_write,
    input logic [3:0] mem_byte_enable,
    // cache -> CPU
    output logic mem_resp,

    // PMEM -> cache
    input logic pmem_resp,
    // cache -> PMEM
    output logic [31:0] pmem_address,
    output logic pmem_read,
    output logic pmem_write,

    // datapath -> control
    input logic hit1,
    input logic hit2,
    input logic old_block_dirty,
    input logic lru_out,
    input logic [23:0] tag1_out,
    input logic [23:0] tag2_out,
    input logic d1,
    input logic d2,
    // control -> datapath
    output logic ld_lru,
    output logic lru_in,
    output logic ld_tag1,
    output logic ld_tag2,
    output logic ld_valid1,
    output logic ld_valid2,
    output logic valid1_in,
    output logic valid2_in,
    output logic ld_dirty1,
    output logic ld_dirty2,
    output logic dirty1_in,
    output logic dirty2_in,
    output logic [1:0] write_en1_sel,
    output logic [1:0] write_en2_sel,
    output logic data_in_sel,
    output logic cacheline_out_sel 
);

logic cpu_request;
assign cpu_request = mem_read ^ mem_write; 


enum int unsigned {
    idle,
    compare_tag,
    write_back,
    allocate
} state, next_state;



function void set_defaults();
    ld_lru = 1'b0;
    lru_in = 1'b0;
    ld_tag1 = 1'b0;
    ld_tag2 = 1'b0;
    write_en1_sel = 2'b0;
    write_en2_sel = 2'b0;
    data_in_sel = 1'b0;
    cacheline_out_sel = 1'b0; 
    ld_valid1 = 1'b0;
    ld_valid2 = 1'b0;
    valid1_in = 1'b0;
    valid2_in = 1'b0;
    ld_dirty1 = 1'b0;
    ld_dirty2 = 1'b0;
    dirty1_in = 1'b0;
    dirty2_in = 1'b0;
    pmem_address = {mem_address[31:5], 5'b0};
    pmem_read = 1'b0;
    pmem_write = 1'b0;
    mem_resp = 1'b0;
endfunction



always_comb
begin: state_actions
    set_defaults();
    unique case (state)
        idle: ;
        compare_tag: begin
            if(hit1) begin
                cacheline_out_sel = 1'b0;
                ld_lru = 1'b1;
                lru_in = 1'b0;
                data_in_sel = 1'b0; // 0:cpu 1:memory
                write_en1_sel = mem_write ? 2'b01 : 2'b00;
                mem_resp = 1'b1;
                ld_dirty1 = mem_write;
                dirty1_in = mem_write || d1;
            end
            else if(hit2) begin
                cacheline_out_sel = 1'b1;
                ld_lru = 1'b1;
                lru_in = 1'b1;
                data_in_sel = 1'b0; // 0:cpu 1:memory
                write_en2_sel = mem_write ? 2'b01 : 2'b00;
                mem_resp = 1'b1;
                ld_dirty2 = mem_write;
                dirty2_in = mem_write || d2;
            end
            else begin
                //miss, do nothing
            end
        end
        write_back: begin
            cacheline_out_sel = ~lru_out;
            pmem_address = lru_out ? {tag1_out, mem_address[7:5], 5'b0} : {tag2_out, mem_address[7:5], 5'b0};
            pmem_write = 1'b1;
        end
        allocate: begin
            cacheline_out_sel = ~lru_out;
            //pmem_address = mem_address
            pmem_read = 1'b1;
            data_in_sel = 1'b1; // 0:cpu 1:memory
            if(lru_out) begin
                write_en1_sel = 2'b11;
                ld_valid1 = 1'b1;
                valid1_in = 1'b1;
                ld_dirty1 = 1'b1;
                dirty1_in = 1'b0;
                ld_tag1 = 1'b1;
            end
            else begin
                write_en2_sel = 2'b11;
                ld_valid2 = 1'b1;
                valid2_in = 1'b1;
                ld_dirty1 = 1'b1;
                dirty1_in = 1'b0;
                ld_tag2 = 1'b1;
            end
        end
        default: ;
    endcase
end



always_comb 
begin: next_state_logic
    if(rst) begin
        next_state = idle;
    end
    else begin
        unique case(state)
            idle: begin
                if(cpu_request)
                    next_state = compare_tag;
                else 
                    next_state = idle;
            end

            compare_tag: begin
                if((~hit1 && ~hit2) && old_block_dirty)
                    next_state = write_back;
                else if(~hit1 && ~hit2) // removed ~old_block_dirty bc it may not be initialized first
                    next_state = allocate;
                else 
                    next_state = idle;
            end

            write_back: begin
                if(pmem_resp)
                    next_state = allocate;
                else 
                    next_state = write_back;
            end

            allocate: begin
                if(pmem_resp)
                    next_state = compare_tag;
                else 
                    next_state = allocate;
            end
            
            default: next_state = idle;
        endcase
    end
end



always_ff @(posedge clk)
begin: next_state_assignment
    state <= next_state;
end

endmodule : cache_control
