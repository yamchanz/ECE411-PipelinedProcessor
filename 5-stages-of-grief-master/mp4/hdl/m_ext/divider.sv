module divider
(
    input logic clk,
    input logic rst,
    input logic load,
    input logic [31:0] dividend,
    input logic [31:0] divisor,
    output logic [31:0] quotient,
    output logic [31:0] remainder,
    output logic div_resp
);

logic [31:0] shift_cnt;
logic [31:0] next_shift_cnt;
logic [31:0] next_quotient;
logic [31:0] next_remainder;

enum int unsigned {
    idle,
    shift,
    done
} state, next_state;
// Next state logic
always_comb begin 
    case(state)
        idle: begin
            if(load) begin
                if((dividend == 32'd0) || (divisor == 32'd0))
                    next_state = done;
                else
                    next_state = shift;
            end
            else
                next_state = idle;
        end
        shift: begin
            if(shift_cnt == -32'd1)
                next_state = done;
            else
                next_state = shift;
        end
        done: begin
            next_state = idle;
        end
        default: next_state = idle;
    endcase
end
// State Action
always_comb begin 
    case(state)
        idle: begin
            next_shift_cnt = 32'd31;
            next_quotient = 32'd0;
            next_remainder = 32'd0;
            div_resp = 1'b0;
        end
        shift: begin
            if(remainder >= divisor) begin
                next_quotient = {quotient[30:0], 1'b1};
                if(shift_cnt < 32'd32)
                    next_remainder = {(remainder[30:0] - divisor[30:0]), dividend[shift_cnt]};
                else
                    next_remainder = remainder - divisor;
            end
            else begin
                next_quotient = {quotient[30:0], 1'b0};
                if(shift_cnt < 32'd32)
                    next_remainder = {remainder[30:0], dividend[shift_cnt]};
                else
                    next_remainder = remainder;
            end
            next_shift_cnt = shift_cnt - 32'd1;
            div_resp = 1'b0;
        end
        done: begin
            next_shift_cnt = 32'd31;
            next_quotient = 32'd0;
            next_remainder = 32'd0;                
            div_resp = 1'b1;
        end
        default: begin
            next_shift_cnt = 32'd31;
            next_quotient = 32'd0;
            next_remainder = 32'd0;
            div_resp = 1'b0;
         end
    endcase
end

always_ff @(posedge clk) begin
    if(rst) begin
        shift_cnt <= 32'd31;
        quotient <= 32'd0;
        remainder <= 32'd0;
        state <= idle;
    end
    else begin
        shift_cnt <= next_shift_cnt;
        quotient <= next_quotient;
        remainder <= next_remainder;
        state <= next_state;
    end
end
endmodule : divider