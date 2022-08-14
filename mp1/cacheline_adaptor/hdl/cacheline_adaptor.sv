module cacheline_adaptor
(
    input clk,
    input reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,
    input logic [31:0] address_i,
    input read_i,
    input write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,
    output logic [31:0] address_o,
    output logic read_o,
    output logic write_o,
    input resp_i
);

logic [255:0] data;

// loads (read) -> 1) buffer data from memory until burst is complete. 2) respond to LLC w/ complete cache line.
// stores (write) -> 1) buffer a cacheline from the LLC. 2) segment the data in blocks for burst trasmission. 3) transmit blocks to memory.

assign load = read_i;
assign store = write_i;
assign address_o = address_i;

always_ff @(posedge clk, negedge reset_n) begin
    if(~reset_n) begin
        read_o = 1'b0;
        write_o = 1'b0;
        resp_o = 1'b0;
    end
    else begin
        case ({load, store})
            2'b00: ;
            2'b01: begin : store_case //write
                write_o <= 1'b1;
                resp_o <= 1'b1;
                for (int i = 0; i < 4; ++i) begin
                    @(clk iff resp_i); begin
                        burst_o <= line_i[64*i +: 64];
                        @(clk);
                    end
                end
                @(posedge clk);
                write_o <= 1'b0;
                resp_o <=1'b0;
            end
            2'b10: begin : load_case //read
                read_o <= 1'b1;
                resp_o <= 1'b1;  
                for (int i = 0; i < 4; ++i) begin
                    @(clk iff resp_i); begin
                        line_o[64*i +: 64] <= burst_i;
                        @(clk);
                    end    
                end
                @(posedge clk);
                //line_o <= data;
                read_o <= 1'b0;
                resp_o <= 1'b0;
            end
            2'b11: ;
        endcase            
    end
end

endmodule : cacheline_adaptor
