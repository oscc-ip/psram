/*
    Copyright 2020 Efabless Corp.

    Author: Mohamed Shalan (mshalan@efabless.com)

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at:
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// psram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "psram_define.sv"

module psram_core (
    input  logic                         clk_i,
    input  logic                         rst_n_i,
    input  logic                         en_i,
    input  logic                         cflg_i,
    input  logic [                  1:0] swm_i,
    output logic [                  1:0] crm_o,
    input  logic [`PSRAM_PSCR_WIDTH-1:0] pscr_i,
    input  logic [                  7:0] wr_cmd_i,
    input  logic [                  7:0] rd_cmd_i,
    input  logic [                  7:0] cfg_cmd_i,
    input  logic [`PSRAM_WAIT_WIDTH-1:0] wait_i,
    input  logic                         tx_valid_i,
    output logic                         tx_ready_o,
    input  logic [                 63:0] tx_data_i,
    output logic                         done_o,
    output logic                         psram_sck_o,
    output logic                         psram_ce_o,
    output logic [                  7:0] psram_io_en_o,
    input  logic [                  7:0] psram_io_in_i,
    output logic [                  7:0] psram_io_out_o
);

  logic s_fsm_d, s_fsm_q;
  logic s_ce_d, s_ce_q, s_sck_d, s_sck_q;
  logic [`PSRAM_PSCR_WIDTH-1:0] s_cnt_d, s_cnt_q;

  assign crm_o       = `PSRAM_MODE_OPI; // TODO: only support OPI mode now
  assign done_o      = 1'b0;
  assign psram_ce_o  = s_ce_q;
  assign psram_sck_o = s_sck_q;

  always_comb begin
    s_fsm_d = s_fsm_q;
    unique case (s_fsm_q)
      `PSRAM_FSM_IDLE: if (tx_valid_i && en_i) s_fsm_d = `PSRAM_FSM_BUSY;
      `PSRAM_FSM_BUSY: if (done_o) s_fsm_d = `PSRAM_FSM_IDLE;
    endcase
  end
  dffr #(1) u_fsm_dffr (
      clk_i,
      rst_n_i,
      s_fsm_d,
      s_fsm_q
  );

  always_comb begin
    s_ce_d = 1'b1;
    if (done_o) s_ce_d = 1'b1;
    else if (s_fsm_q == `PSRAM_FSM_BUSY) s_ce_d = 1'b0;
  end
  dffrh #(1) u_ce_dffr (
      clk_i,
      rst_n_i,
      s_ce_d,
      s_ce_q
  );

  always_comb begin
    s_cnt_d = s_cnt_q;
    if (~s_ce_q) begin
      if (s_cnt_q == '0) s_cnt_d = pscr_i;
      else s_cnt_d = s_cnt_q - 1'b1;
    end
  end
  dffr #(`PSRAM_PSCR_WIDTH) u_cnt_dffr (
      clk_i,
      rst_n_i,
      s_cnt_d,
      s_cnt_q
  );

  always_comb begin
    s_sck_d = s_sck_q;
    if (done_o) s_sck_d = 1'b0;
    else if (~s_ce_q && s_cnt_q == '0) s_sck_d = ~s_sck_q;
  end
  dffr #(1) u_sck_dffr (
      clk_i,
      rst_n_i,
      s_sck_d,
      s_sck_q
  );


  // // The transaction counter
  // wire [7:0] wait_start = (~qpi ? 8 : 2)  // The command 
  // + ((qpi | qspi) ? 6 : 24);  // The Address        
  // wire [7:0] data_start = wait_start + (rd_wr ? wait_states : 0);
  // wire [7:0] data_count = ((qpi | qspi) ? 2 : 8) * size;
  // wire [7:0] final_count = short_cmd ? 8 : data_start + data_count;

  // assign done = (counter == final_count);

  // always @(posedge clk or negedge rst_n)
  //   if (!rst_n) counter <= 8'b0;
  //   else if (sck & ~done) counter <= counter + 1'b1;
  //   else if (state == IDLE) counter <= 8'b0;

  // if cflg is TRUE, use 

endmodule
