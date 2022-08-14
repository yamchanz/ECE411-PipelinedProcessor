import mult_types::*;

`ifndef testbench
`define testbench
module testbench(multiplier_itf.testbench itf);

add_shift_multiplier dut (
    .clk_i          ( itf.clk          ),
    .reset_n_i      ( itf.reset_n      ),
    .multiplicand_i ( itf.multiplicand ),
    .multiplier_i   ( itf.multiplier   ),
    .start_i        ( itf.start        ),
    .ready_o        ( itf.rdy          ),
    .product_o      ( itf.product      ),
    .done_o         ( itf.done         )
);

assign itf.mult_op = dut.ms.op;
default clocking tb_clk @(negedge itf.clk); endclocking

// DO NOT MODIFY CODE ABOVE THIS LINE

/* Uncomment to "monitor" changes to adder operational state over time */
//initial $monitor("dut-op: time: %0t op: %s", $time, dut.ms.op.name);



// MY CODE
logic [7:0] multiplicand;
logic [7:0] multiplier;
logic [15:0] product;
assign itf.multiplicand = multiplicand;
assign itf.multiplier = multiplier;
assign product = multiplicand * multiplier;

task do_multipication();
    @(posedge itf.clk);
    itf.start <= 1'b1;
    @(posedge itf.clk);
    itf.start <= 1'b0;
    @(posedge itf.done);
    assert (itf.product == product)
        else begin 
            $error ("%0d: %0t: BAD_PRODUCT error detected", `__LINE__, $time);
            report_error (BAD_PRODUCT);
        end
    assert (itf.rdy == 1'b1)
        else begin 
            $error ("%0d: %0t: NOT_READY error detected", `__LINE__, $time);
            report_error (NOT_READY);
        end
endtask : do_multipication

task do_reset_in_add();
    @(posedge itf.clk);
    itf.start <= 1'b1;
    @(posedge itf.clk);
    itf.start <= 1'b0;
    while (1) begin
        @(posedge itf.clk);
        if (dut.ms.op == ADD) begin
            @(posedge itf.clk);
            itf.reset_n <= 1'b0;            
            @(posedge itf.clk);
            itf.reset_n <= 1'b1;
            @(posedge itf.clk);
            assert (itf.rdy == 1'b1)
                else begin 
                    $error ("%0d: %0t: NOT_READY error detected", `__LINE__, $time);
                    report_error (NOT_READY);
            end
            break;
        end
    end
endtask: do_reset_in_add

task do_reset_in_shift();
    @(posedge itf.clk);
    itf.start <= 1'b1;
    @(posedge itf.clk);
    itf.start <= 1'b0;
    while (1) begin
        @(posedge itf.clk);
        if (dut.ms.op == SHIFT) begin
            @(posedge itf.clk);
            itf.reset_n <= 1'b0;            
            @(posedge itf.clk);
            itf.reset_n <= 1'b1;
            @(posedge itf.clk);
            assert (itf.rdy == 1'b1)
                else begin 
                    $error ("%0d: %0t: NOT_READY error detected", `__LINE__, $time);
                    report_error (NOT_READY);
            end
            break;
        end
    end
endtask: do_reset_in_shift

task do_start_in_add();
    @(posedge itf.clk);
    itf.start <= 1'b1;
    @(posedge itf.clk);
    itf.start <= 1'b0;
    while (1) begin
        @(posedge itf.clk);
        if (dut.ms.op == ADD) begin
            @(posedge itf.clk);
            itf.start <= 1'b1;            
            @(posedge itf.clk);
            itf.start <= 1'b0;
            break;
        end
    end
    @(posedge itf.clk);
    itf.reset_n <= 1'b0;            
    @(posedge itf.clk);
    itf.reset_n <= 1'b1;
endtask: do_start_in_add

task do_start_in_shift();
    @(posedge itf.clk);
    itf.start <= 1'b1;
    @(posedge itf.clk);
    itf.start <= 1'b0;
    while (1) begin
        @(posedge itf.clk);
        if (dut.ms.op == SHIFT) begin
            @(posedge itf.clk);
            itf.start <= 1'b1;            
            @(posedge itf.clk);
            itf.start <= 1'b0;
            break;
        end
    end
    @(posedge itf.clk);
    itf.reset_n <= 1'b0;            
    @(posedge itf.clk);
    itf.reset_n <= 1'b1;
endtask: do_start_in_shift



// Resets the multiplier
task reset();
    itf.reset_n <= 1'b0;
    ##5;
    itf.reset_n <= 1'b1;
    ##1;
endtask : reset

// error_e defined in package mult_types in file ../include/types.sv
// Asynchronously reports error in DUT to grading harness
function void report_error(error_e error);
    itf.tb_report_dut_error(error);
endfunction : report_error


initial itf.reset_n = 1'b0;
initial begin
    reset();
    /********************** Your Code Here *****************************/

    for (int i = 0; i < 9'b100000000; ++i) begin
        for(int j = 0; j < 9'b100000000; ++j) begin
            multiplicand = i[7:0];
            multiplier = j[7:0];
            do_multipication();
        end
    end

    multiplicand = 8'b00000111;
    multiplier = 8'b00000010;
    do_reset_in_add();
    do_reset_in_shift();
    do_start_in_add();
    do_start_in_shift();

    /*******************************************************************/
    itf.finish(); // Use this finish task in order to let grading harness
                  // complete in process and/or scheduled operations
    $error("Improper Simulation Exit");
end


endmodule : testbench
`endif
