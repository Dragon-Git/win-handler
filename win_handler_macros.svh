//=============================================================================
//  @brief  Macro definitions
//  @author Jeffery Vance, Verilab (www.verilab.com)
// =============================================================================
//
//                      Window Handler Technique Implementation
//
// @File: win_handler_macros.svh
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



`define config_win_handler_begin(CLASS_NAME,TYPE)                     \
  class ``CLASS_NAME #(type T=``TYPE ) extends win_handler_base;      \
    local T m_exp_win_tr;                                             \
    function new(string name);                                        \
      m_name = name;                                                  \
      m_exp_win_tr = new();                                           \
      m_msg_printer = new();                                          \
    endfunction                                                       \
    function void set_exp_data(input T tr);                           \
      m_set_tmp_and_win_tr(tr);                                       \
      m_fields_exp = m_fields_tmp;                                    \
    endfunction                                                       \
    function void set_act_data(T tr);                                 \
      m_set_tmp_and_win_tr(tr);                                       \
      m_check_change();                                               \
      m_fields_act = m_fields_tmp;                                    \
      m_set_win_data();                                               \
      m_prev_vals = m_fields_act;                                     \
    endfunction                                                       \
    function T get_exp_data();                                        \
      m_set_tmp_and_win_tr();                                         \
      return m_exp_win_tr;                                            \
    endfunction                                                       \
    protected function void m_set_tmp_and_win_tr(input T tr=null);

    //-------------------------------------------------------------------------------------
    //set_tmp_and_win_tr():  This function serves 2 purposes:
    // 1. Provide mapping of transaction member to a string index for an assoc array.
    // 2. Provide reverse mapping of entries in assoc array to a window compensated transaction object.
    // If a tr parameter is passed, both operations will be performed.
    // If no tr is passed, only the 2nd operation is performed.
    // Full definition of function relies on user calling macros for each field.
    //-------------------------------------------------------------------------------------


// Each invocation of this macro adds a statement to the
//   m_set_tmp_and_win_tr() function.

`define set_win_field(VAR_NAME, STR_NAME)              \
      if(tr != null) begin                             \
        m_fields_tmp[STR_NAME] = tr.VAR_NAME;          \
      end                                              \
      m_exp_win_tr.VAR_NAME  = m_fields_win[STR_NAME];  // Put latest window compensated predictions in a transaction object


// End function and class of window handler
`define config_win_handler_end            \
    endfunction : m_set_tmp_and_win_tr    \
  endclass


