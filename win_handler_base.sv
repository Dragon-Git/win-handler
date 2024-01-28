//=============================================================================
//  @brief  Window handler base class definitions
//  @author Jeffery Vance, Verilab (www.verilab.com)
// =============================================================================
//
//                      Window Handler Technique Implementation
//
// @File: win_handler_base.sv
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

// win_msg_printer class is meant to be extended so custom msg handling can be applied.
//   For example, to apply UVM, messaging:
//     -- override print_info() to use `uvm_info() with msg string (setting verbosity as desired)
//     -- override print_error() to use `uvm_error() with msg string 

class win_msg_printer;

  function new();
  endfunction

  virtual function print_info(string name, string msg);
    $display("WIN_HANDLER_INFO @ %0t (%s): %s", $realtime(), name, msg);
  endfunction

  virtual function print_error(string name, string msg);
    $display("WIN_HANDLER_ERROR @ %0t (%s): %s", $realtime(), name, msg);
  endfunction
endclass



// Base win handler class
virtual class win_handler_base;

  string m_name;

  // Associate arrays to store expected, actual, and win compensated values.
  //  These are indexed by string provided by macros for each field.

  protected bit [`WIN_MAX_DATA_WIDTH-1:0] m_fields_exp[string];
  protected bit [`WIN_MAX_DATA_WIDTH-1:0] m_fields_act[string];
  protected bit [`WIN_MAX_DATA_WIDTH-1:0] m_fields_win[string];
  protected bit [`WIN_MAX_DATA_WIDTH-1:0] m_fields_tmp[string];

  protected bit [`WIN_MAX_DATA_WIDTH-1:0] m_prev_vals[string];       //Store previous value for eatch field
  protected bit m_volatile[string];        //Entries set with 1 are volatile.
  protected bit m_prev_val_modes[string];  //Entries set with 1 can only be next or prev value.
                                           //  0 - entries can be any value during window


  // Window Status and Event variables
  protected event      m_pre_win_event;      //Event to indicate window will start after win_delay time.
  protected event      m_in_window_event;    // Triggered when timing window begins.
  protected event      m_set_act_event;      // Triggered when act data is set
  protected event      m_end_win_early_event;

  protected bit        m_in_window;          // Status bit:  1= currently in window, 0=out of window
  protected bit        m_trans_in_window;    // 1 Indicates the actual value transitioned during the timing window.

  // Bookkeeping variables
  protected time m_win_start_time;  // Time of last window start
  protected time m_win_end_time;    // Time the last window ended.
  protected time m_trans_time;      // Time of last transition relative to window start time.

  int unsigned m_num_windows = 0;    // Count number of unknown windows that occured
  int unsigned m_num_outside = 0;    // Count number of transactions that occured outside window
  int unsigned m_num_not_masked = 0; // Count number of times expected volatile value matched actual and didn't need a mask in window
  int unsigned m_num_masked = 0;     // Count number of times a volatile value is masked in the window
                                     //    Note: only count the times exp value had to change to avoid false error.

  // Configuration variables
  protected time m_window_duration; // Set how long the window lasts
  protected time m_start_delay = 0; // Set delay between window event and start of actual window (default 0)

  // Status and Mode variables
  protected bit  m_multi_trans_mode = 0; // 1 indicates actual value can have multiple transitions in window without error.
  protected bit  m_configured = 0;       // indicates if handler has been configured.
  protected bit  m_monitoring_on = 0;    // indicates if handler is actively monitoring the window.
  protected bit  m_first_start = 1;      // 1 indicates that the window handler is being started for the first time.

  // Print message class
  win_msg_printer  m_msg_printer;   // This instance is used to print logging messages (extend class for custom display)

  //--------------------------
  // Configuration Methods
  //--------------------------
  function void set_volatile_field(string name, bit prev_val_mode=0);
    m_volatile[name] = 1;
    m_prev_val_modes[name] = prev_val_mode;
  endfunction

  function void configure(event win_event, time duration, time start_delay=0);
    m_pre_win_event   = win_event;
    m_window_duration = duration;
    m_start_delay     = start_delay;
    m_configured      = 1;
  endfunction

  function void set_mode(bit multi_trans=0);
    m_multi_trans_mode = multi_trans;
  endfunction


  //--------------------------
  // Control/access Methods
  //--------------------------

  // This function sets a flag to start monitoring window events.
  // Without calling this function, the handler won't do anything.
  // Handler must be configured with configure() before calling start()

  function void start();


    if(m_first_start == 1) begin  // If starting window handler for the first time
      m_first_start = 0;

      fork
        run_monitor();
      join_none
    end

    if(m_monitoring_on == 1) begin
      m_msg_printer.print_info(m_name, "Window handler is already on.");
      return;
    end

    m_msg_printer.print_info(m_name, "Starting Window Handler");

    if(m_configured == 1) begin
      m_monitoring_on = 1;
    end
    else begin
      m_msg_printer.print_error(m_name, "Window handler must be configured before it can be started.");
    end
  endfunction


  // This function will set a flag to stop monitoring window events.
  // While stopped, all expected values will be unmodified relative
  // to timing windows.
  function void stop();
    m_msg_printer.print_info(m_name, "Stopping Window Handler");
    m_monitoring_on = 0;
  endfunction


  // Function: check_act_data()
  // Check actual data against expected data.
  // If in timing window, compensated values are used,
  // Otherwise, the original expected data is used.

  function bit check_act_data();
    string s;
    bit    error_found = 0;

    foreach(m_fields_act[s]) begin

      if(m_in_window == 1) begin
        if(m_fields_act[s] != m_fields_win[s]) begin

          error_found = 1;
          m_msg_printer.print_error(m_name, $sformatf("Mismatch of %s (inside window): act = %0h, masked exp = %0h, default exp = %0h",
                                              s, m_fields_act[s], m_fields_win[s], m_fields_exp[s]));
        end
      end
      else begin  //outside window

        if(m_fields_act[s] != m_fields_exp[s]) begin
          error_found = 1;
          m_msg_printer.print_error(m_name, $sformatf("Mismatch of %s (outside window): act = %0h, default exp = %0h",
                                              s, m_fields_act[s], m_fields_exp[s]));
        end
      end
    end

    return  ~error_found; //Return 1 if all data matches.  Return 0 if there's an error.

  endfunction

  // Use this function to request status of the unknown window
  function bit in_window();
    return m_in_window;
  endfunction

  // Print bookkeeping data
  function void print_stats();
    string msg;

    msg = "\n----WIN HANDLER STATS----\n";
    msg = $sformatf("%s Number of unknown windows: %0d\n",                     msg, m_num_windows);
    msg = $sformatf("%s Number of exp values changed in window: %0d\n",        msg, m_num_masked);
    msg = $sformatf("%s Number of exp values NOT changed in window: %0d\n",    msg, m_num_not_masked);
    msg = $sformatf("%s Number of transactions outside window: %0d\n",         msg, m_num_outside);

    m_msg_printer.print_info(m_name, msg);
  endfunction

  // Use this function to request to end window early
  function void end_window();
    if(m_in_window == 1) begin
      ->m_end_win_early_event;
    end
    else begin
      m_msg_printer.print_info(m_name, "Not currently in unknown window. Request to end window early ignored");
    end
  endfunction

  //--------------------------
  // Protected Methods
  //--------------------------
  protected task run_monitor();

    forever begin

      //Block thread if monitoring is turned OFF
      wait(m_monitoring_on == 1);

      fork begin
        fork
          begin
            @(m_pre_win_event);
            #(m_start_delay);  //Wait start delay (default is 0)

            m_msg_printer.print_info(m_name, "Entering unknown window.");
            m_in_window = 1;
            m_win_start_time = $realtime();
            m_num_windows++;

            #(m_window_duration);   // Wait full window duration.

            m_msg_printer.print_info(m_name, "Exiting unknown window.");
            m_win_end_time = $realtime();
            m_in_window = 0;
            m_trans_in_window = 0;   //reset flag in case it was set
          end
          begin
            //Terminate above thread if monitoring is turned off
            wait(m_monitoring_on == 0);

            if(m_in_window == 1) begin
              m_msg_printer.print_info(m_name, "Turning monitoring OFF during window.");
            end
            m_in_window = 0;
            m_trans_in_window = 0;
          end
          begin
            //Terminate above threads on event to end early
            @(m_end_win_early_event);

            if(m_in_window == 1) begin
              m_msg_printer.print_info(m_name, "Ending window early.");
            end
            m_in_window = 0;
            m_trans_in_window = 0;
          end
        join_any
        disable fork;
      end join
    end
  endtask

  // This function checks if any volatile fields changed during the unknown window
  //   Note:  it is assumed that m_set_tmp_and_win() is called prior to this function
  //          so that the latest output data is in the tmp_array has latest values.
  protected function void m_check_change();
    string s;
    time time_left;   //calculate remaining time in window based on duration

    if(m_in_window == 1) begin

      foreach(m_fields_tmp[s]) begin
        if( (m_volatile[s] == 1) &&
            (m_fields_tmp[s] != m_prev_vals[s]) ) begin

          m_trans_in_window = 1;
          m_trans_time = $realtime() - m_win_start_time;
          time_left = m_window_duration - m_trans_time;

          m_msg_printer.print_info(m_name, $sformatf("Actual %s changed %0t into window (%0t until window end). Prev = %0h, New = %0h",
                                              s, m_trans_time, time_left, m_prev_vals[s], m_fields_tmp[s]));
        end
      end
    end
  endfunction : m_check_change


  protected function m_set_win_data();

    string s;

    // If we're currently in timing window
    if(m_in_window == 1) begin

        foreach(m_fields_exp[s]) begin

          //Volatile fields in single transition mode are set equal to actual.
          if(m_volatile[s] == 1) begin

            // Prev Val Mode can only be exp or prev value
            if(m_prev_val_modes[s] == 1) begin

              if(m_fields_act[s] == m_prev_vals[s]) begin

                m_msg_printer.print_info(m_name, $sformatf("Changing %s expected value of %0h to equal previous value of %0h",
                                                    s, m_fields_exp[s], m_prev_vals[s]));
                m_fields_win[s] = m_fields_act[s];
                m_num_masked++;
              end
              else if(m_fields_act[s] == m_fields_exp[s]) begin
                m_fields_win[s] = m_fields_exp[s];  // Keep expected value for checking (no masking)
                m_num_not_masked++;
              end
              else begin
                m_msg_printer.print_error(m_name, $sformatf("%s: Actual value (%0h) does not equal expected (%0h) or previous (%0h)",
                                                      s, m_fields_act[s], m_fields_exp[s], m_prev_vals[s]));
              end
            end // if prev_val_modes==1
            else begin  // Otherwise, it can be any value, so match any value of actual

              if(m_fields_act[s] != m_fields_exp[s]) begin

                m_msg_printer.print_info(m_name, $sformatf("Changing %s expected value of %0h to equal actual value of %0h",
                                                    s, m_fields_exp[s], m_fields_act[s]));
                m_fields_win[s] = m_fields_act[s];
                m_num_masked++;
              end
              else begin
                m_fields_win[s] = m_fields_exp[s];  // Use original expected value
                m_num_not_masked++;
              end
            end
          end // if volatile
          else begin
            m_fields_win[s] = m_fields_exp[s];      // non-volatile fields are kept same as exp
          end
        end  // foreach

        if( m_multi_trans_mode == 0 && m_trans_in_window == 1) begin

          // In this mode actual value can only change once.
          // After masking this change, we end the window early.
          ->m_end_win_early_event;
        end

    end // if in_window
    else begin
      m_fields_win = m_fields_exp;  // Not currently in window, use normal expected values.
      m_num_outside++;
    end
  endfunction : m_set_win_data

endclass


