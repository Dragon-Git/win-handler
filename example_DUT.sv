//=============================================================================
//  @brief  Example DUT for demonstrating window handler technique
//  @author Jeffery Vance, Verilab (www.verilab.com)
// =============================================================================
//
//                      Window Handler Technique Implementation
//
// @File: example_DUT.sv
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
// Module outputs a count that increments every 5 to 10 clks
// Output is considered valid when valid_out == 1.
// On posedge of reset_count, count resets to 0 anywhere up to 30 clks later
//   - Note: On reset, count will stop incrementing, but may remain outputing at current count
//            value for several transactions until actual reset to 0 occurs.
// Note: Example DUT is only for testbench simulation demonstration purposes.


`timescale 1ms/1us

module ex_1_DUT( clk, rst, count_out, parity_out, valid_out);

  input clk;
  input rst;
  output [31:0] count_out;
  output        parity_out;
  output        valid_out;

  bit[31:0]  count_val;    //internal counter state
  bit[31:0]  count_output;
  bit        parity;
  bit        valid;
  bit        rst_pending;  //internal signal

  int unsigned  rst_delay;
  int unsigned  valid_delay;

  initial begin
    count_val = 0;
    parity = 0;
    valid = 0;
    rst_pending = 0;
  end


  // On reset, reset count value to 0 up to 30 clks later

  always @(posedge rst) begin
    rst_pending = 1;
    rst_delay = $urandom_range(0, 30);
    repeat(rst_delay) @(posedge clk);
    count_val = 0;
    count_output = 0;
    rst_pending = 0;
  end


  // Output count transaction every 5 to 10 ms
  //   values held for 1 clk.

  always @(posedge clk) begin
    valid_delay = $urandom_range(5,10);
    repeat(valid_delay) @(posedge clk);

    @(posedge clk)  //wait until next posedge

    if(rst_pending == 0) begin
      count_val++;
    end

    parity = ^count_val;

    count_output = count_val;
    valid = 1;

    @(posedge clk);  //hold output value for 1 clk
    count_output = 0;
    parity = 0;
    valid = 0;
  end


  assign count_out  = count_output;
  assign parity_out = parity;
  assign valid_out  = valid;

endmodule

