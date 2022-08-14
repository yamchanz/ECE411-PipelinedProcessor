import cam_types::*;

module testbench(cam_itf itf);

cam dut (
    .clk_i     ( itf.clk     ),
    .reset_n_i ( itf.reset_n ),
    .rw_n_i    ( itf.rw_n    ),
    .valid_i   ( itf.valid_i ),
    .key_i     ( itf.key     ),
    .val_i     ( itf.val_i   ),
    .val_o     ( itf.val_o   ),
    .valid_o   ( itf.valid_o )
);

default clocking tb_clk @(negedge itf.clk); endclocking

task reset();
    itf.reset_n <= 1'b0;
    repeat (5) @(tb_clk);
    itf.reset_n <= 1'b1;
    repeat (5) @(tb_clk);
endtask

// DO NOT MODIFY CODE ABOVE THIS LINE

key_t key_p;
val_t value_p;

task write(input key_t key, input val_t val);
    // cam size = 8, each key->value pair = 16
    @(posedge itf.clk);
    itf.key <= key;
    itf.val_i <= val;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
endtask: write

task read(input key_t key, output val_t val);
    @(posedge itf.clk);
    itf.key <= key;
    itf.rw_n <= 1'b1;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    val <= itf.val_o;
    itf.valid_i <= 1'b0;
    ##(1);
endtask: read

task do_write_write();
    @(posedge itf.clk);
    itf.key <= 16'h0001;
    itf.val_i <= 16'hfeed;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk);
    itf.key <= 16'h0001;
    itf.val_i <= 16'hbeef;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
endtask: do_write_write

task do_write_read();
    @(posedge itf.clk);
    itf.key <= 16'h0001;
    itf.val_i <= 16'hfeed;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk);
    itf.key <= 16'h0001;
    itf.rw_n <= 1'b1;
    itf.valid_i <= 1'b1;
    @(posedge itf.clk)
    itf.valid_i <= 1'b0;
endtask: do_write_read

initial begin
    $display("Starting CAM Tests");

    reset();
    /************************** Your Code Here ****************************/
    // Feel free to make helper tasks / functions, initial / always blocks, etc.
    // Consider using the task skeltons above
    // To report errors, call itf.tb_report_dut_error in cam/include/cam_itf.sv
    
    for (int i = 0; i < 16; ++i) begin
        key_p = i;
        value_p = i;
        write(key_p, value_p);
    end

    for (int i = 8; i < 16; ++i) begin
        key_p = i;
        read(key_p, value_p);
        assert (value_p == i)
            else begin
                $error ("0%d: 0%t: READ_ERROR detected", `__LINE__, $time);
                itf.tb_report_dut_error (READ_ERROR);
            end
    end

    do_write_write();
    do_write_read();


    /**********************************************************************/

    itf.finish();
end

endmodule : testbench
