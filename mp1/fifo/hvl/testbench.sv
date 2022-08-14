`ifndef testbench
`define testbench

import fifo_types::*;

module testbench(fifo_itf itf);

fifo_synch_1r1w dut (
    .clk_i     ( itf.clk     ),
    .reset_n_i ( itf.reset_n ),

    // valid-ready enqueue protocol
    .data_i    ( itf.data_i  ),
    .valid_i   ( itf.valid_i ),
    .ready_o   ( itf.rdy     ),

    // valid-yumi deqeueue protocol
    .valid_o   ( itf.valid_o ),
    .data_o    ( itf.data_o  ),
    .yumi_i    ( itf.yumi    )
);

// Clock Synchronizer for Student Use
default clocking tb_clk @(negedge itf.clk); endclocking

task reset();
    itf.reset_n <= 1'b0;
    ##(10);
    itf.reset_n <= 1'b1;
    ##(1);
endtask : reset

function automatic void report_error(error_e err); 
    itf.tb_report_dut_error(err);
endfunction : report_error

// DO NOT MODIFY CODE ABOVE THIS LINE



// MY CODE
logic word;
assign itf.data_i = word;

task do_enqueue();
    //width = 8bits, capacity = 1<<8 = 256
    @(posedge itf.clk)
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
endtask: do_enqueue

task do_dequeue();
    @(posedge itf.clk)
    itf.yumi <= 1'b1;
    assert (word == itf.data_o)
        else begin
            $error ("%0d: %0t: INCORRECT_DATA_O_ON_YUMI_I error detected", `__LINE__, $time);
            report_error (INCORRECT_DATA_O_ON_YUMI_I);
        end
    @(posedge itf.clk)
    itf.yumi <= 1'b0;
endtask: do_dequeue

task do_simultaneous();
    @(posedge itf.clk)
    itf.valid_i <= 1'b1;
    itf.yumi <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
    itf.yumi <= 1'b0;
endtask: do_simultaneous

task do_reset();
    @(tb_clk);
    reset();
    @(posedge itf.clk);
    assert (itf.rdy)
        else begin
            $error ("%0d: %0t:  RESET_DOES_NOT_CAUSE_READY_O error detected", `__LINE__, $time);
            report_error (RESET_DOES_NOT_CAUSE_READY_O);
        end
endtask: do_reset



initial begin
    reset();
    /************************ Your Code Here ***********************/
    // Feel free to make helper tasks / functions, initial / always blocks, etc.

    for (int i = 0; i < 256; ++i) begin
        word = i[7:0];
        do_enqueue();
    end

    for (int i = 0; i < 256; ++i) begin
        word = i[7:0];
        do_dequeue();
    end

    word = 8'b0;
    for (int i = 1; i < 256; ++i) begin
        do_enqueue();
        word = i[7:0];
        do_simultaneous();
    end

    do_reset();

    /***************************************************************/
    // Make sure your test bench exits by calling itf.finish();
    itf.finish();
    $error("TB: Illegal Exit ocurred");
end

endmodule : testbench
`endif

