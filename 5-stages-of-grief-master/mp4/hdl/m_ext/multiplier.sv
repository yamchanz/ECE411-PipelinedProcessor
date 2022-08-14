module multiplier
(
    input logic clk,
    input logic rst,
    input logic load,
    input logic [31:0] multiplicand,
    input logic [31:0] multiplier,
    output logic [63:0] product,
    output logic mul_resp
);

logic [31:0] add_value;
logic [31:0] shift_end;
logic [31:0] shift_cnt;
logic [31:0] next_shift_cnt;
logic [63:0] next_product;

enum int unsigned {
    idle,
    shift,
    done
} state, next_state;

assign shift_end = (multiplicand > multiplier) ? (multiplier - 32'd1) : (multiplicand - 32'd1);
assign add_value = (multiplicand > multiplier) ? multiplicand : multiplier;
// Next state logic
always_comb begin 
    case(state)
        idle: begin
            if(load) begin
                if((multiplicand == 32'd0) || (multiplier == 32'd0))
                    next_state = done;
                else
                    next_state = shift;
            end
            else
                next_state = idle;
        end
        shift: begin
            if(shift_cnt == shift_end)
                next_state = done;
            else
                next_state = shift;
        end
        done: next_state = idle;
        default: next_state = idle;
    endcase
end
// State Action
always_comb begin 
    case(state)
        idle: begin
            next_shift_cnt = 32'd0;
            next_product = 64'd0;
            mul_resp = 1'b0;
        end
        shift: begin
            next_product = product + add_value;
            next_shift_cnt = shift_cnt + 32'd1;
            mul_resp = 1'd0;
        end
        done: begin
            next_shift_cnt = 32'd0;
            next_product = 64'd0;             
            mul_resp = 1'b1;
        end
        default: begin
            next_shift_cnt = 32'd0;
            next_product = 64'd0;
            mul_resp = 1'b0;
        end
    endcase
end

always_ff @(posedge clk) begin 
    if(rst) begin
        shift_cnt <= 32'd0;
        product <= 64'd0;
        state <= idle;
    end
    else begin
        shift_cnt <= next_shift_cnt;
        product <= next_product;
        state <= next_state;
    end
end

endmodule : multiplier