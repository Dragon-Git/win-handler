//=============================================================================
//  @brief  Example Testbench using window handler
//  @author Jeffery Vance, Verilab (www.verilab.com)
// =============================================================================
//
//                      Window Handler Technique Implementation
//
// @File: example_TB.sv
//
// Copyright 2014 Verilab, Inc.
// 
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
// 
//        http://www.apache.org/licenses/LICENSE-2.0
// 
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
//=============================================================================

`define WIN_MAX_DATA_WIDTH  32


`include "example_DUT.sv"
`include "win_handler_macros.svh"
`include "win_handler_base.sv"

class count_tr;

  bit[31:0] count;  // This field will be configured volatile, single transition mode, any value allowed.
  bit parity;  // This is non-volatile.  Parity is fully deterministic based on current count

  function new();
    count = 0;
    parity = 0;
  endfunction
endclass


module ex1_tb_top;


  bit clk = 0;
  always #5 clk = !clk;

  logic        rst;
  logic [31:0] count_out;
  logic        parity_out;
  logic        valid_out;

  event        rst_event;
  bit          rst_pending;

  count_tr   act_tr = new();
  count_tr   exp_tr = new();

  ex_1_DUT  DUT(.*);

  //Define win-handler class name and tr type
  `config_win_handler_begin(count_win_handler, count_tr)
    `set_win_field(count,  "count")
    `set_win_field(parity, "parity")
  `config_win_handler_end

  count_win_handler  whandler = new("whandler");

  //Configure win handler
  initial begin
    whandler.set_volatile_field("count", 1); // Use previous value mode
    whandler.configure(rst_event, 410ms);    // Allow 410ms duration window (allows up to 30 clks for reset + time for next tr)
    whandler.set_mode(0);                    // Don't allow multiple transitions of count in window (it only resets once)
    whandler.start();
  end

  // Driver thread
  initial begin

    for(int i=0; i<= 500; i++) begin

      repeat(80) @(posedge clk);
      $display("TB @ %0t : Reseting counter", $realtime());

      rst = 1;
      @(posedge clk);
      rst = 0;
    end

    whandler.print_stats();
    $finish;
  end


  // Monitor threads

  initial begin

    exp_tr.count = 1;
    whandler.set_exp_data(exp_tr);  // Set initial expected values

    forever begin

      @(posedge valid_out);
      act_tr.count = count_out;
      act_tr.parity = parity_out;

      $display("TB @ %0t : Saw Actual Count of %0d", $realtime(), act_tr.count);

      // Parity is always calculated on actual output
      exp_tr.parity = ^act_tr.count;
      whandler.set_exp_data(exp_tr);  //Update expected with parity calculation

      whandler.set_act_data(act_tr);


      whandler.check_act_data();

      if((rst_pending == 1) && (act_tr.count == 1)) begin // reset finished
        rst_pending = 0;
      end

      if(rst_pending == 0) begin
        exp_tr.count++;
      end

      //Update expected value for next transaction
      whandler.set_exp_data(exp_tr);
    end
  end

  initial begin
    forever begin
      @(posedge rst)
      ->rst_event;
      rst_pending = 1;
      #1;
      exp_tr.count = 1;  //reset count

      whandler.set_exp_data(exp_tr);
    end
  end


endmodule



