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

`include "shift_reg.sv"
`include "psram_define.sv"

// inter_clk : psram_clk = 4 : 1
// 1: rd 0: wr
module psram_core (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        cfg_cflg_i,
    input  logic [ 1:0] cfg_pscr_i,
    input  logic [ 7:0] cfg_recy_i,
    input  logic [ 7:0] cfg_wcmd_i,
    input  logic [ 7:0] cfg_rcmd_i,
    input  logic [ 7:0] cfg_ccmd_i,
    input  logic [ 7:0] cfg_wlc_i,
    input  logic [ 7:0] cfg_rlc_i,
    input  logic [31:0] cfg_addr_i,
    input  logic [ 7:0] cfg_data_i,
    input  logic        xfer_en_i,
    input  logic        xfer_rdwr_i,
    output logic        psram_sck_o,
    output logic        psram_ce_o,
    output logic [ 7:0] psram_io_en_o,
    input  logic [ 7:0] psram_io_in_i,
    output logic [ 7:0] psram_io_out_o,
    output logic        psram_dqs_en_o,
    input  logic        psram_dqs_in_i,
    output logic        psram_dqs_out_o
);

  logic s_psram_clk_trg, s_psram_clk;
  logic [2:0] s_fsm_state_d, s_fsm_state_q;
  logic [7:0] s_fsm_cnt_d, s_fsm_cnt_q, s_div_val;

  assign psram_ce_o      = '0;
  assign psram_sck_o     = psram_ce_o == 1'b0 ? s_psram_clk : '0;
  assign psram_io_en_o   = '0;
  assign psram_io_out_o  = '0;
  assign psram_io_en_o   = '0;
  assign psram_dqs_out_o = '0;

  always_comb begin
    s_div_val = 8'd3;
    unique case (cfg_pscr_i)
      `PSRAM_PSCR_DIV4:  s_div_val = 8'd3;
      `PSRAM_PSCR_DIV8:  s_div_val = 8'd7;
      `PSRAM_PSCR_DIV16: s_div_val = 8'd15;
      `PSRAM_PSCR_DIV32: s_div_val = 8'd31;
    endcase
  end
  // due to set one-time in init phase, set `div_valid_i` to `1` is ok
  clk_int_div_simple #(
      .DIV_VALUE_WIDTH (8),
      .DONE_DELAY_WIDTH(3)
  ) u_clk_int_div_simple (
      .clk_i      (clk_i),
      .rst_n_i    (rst_n_i),
      .div_i      (s_div_val),
      .div_valid_i(1'b1),
      .div_ready_o(),
      .div_done_o (),
      .clk_trg_o  (s_psram_clk_trg),
      .clk_o      (s_psram_clk)
  );


  always_comb begin
    s_fsm_state_d = s_fsm_state_q;
    s_fsm_cnt_d   = s_fsm_cnt_q;
    unique case (s_fsm_state_q)
      `PSRAM_FSM_IDLE: begin
        if (xfer_en_i) begin
          s_fsm_state_d = `PSRAM_FSM_INST;
          s_fsm_cnt_d   = 8'd1;
        end
      end
      `PSRAM_FSM_INST: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_ADDR;
          s_fsm_cnt_d   = 8'd3;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_ADDR: begin
        if (s_fsm_cnt_q == '0) begin
          if (cfg_cflg_i && cfg_ccmd_i == 8'hFF) begin  // FOR GLOBAL RESET CMD
            s_fsm_state_d = `PSRAM_FSM_RECY;
            s_fsm_cnt_d   = cfg_recy_i;
          end else if (cfg_cflg_i && ~xfer_rdwr_i) begin
            s_fsm_state_d = `PSRAM_FSM_WDATA;
            s_fsm_cnt_d   = 8'd2;  // compose one word for right xfer
          end else begin
            s_fsm_state_d = `PSRAM_FSM_LATN;
            s_fsm_cnt_d   = xfer_rdwr_i ? cfg_rlc_i : cfg_wlc_i;
          end
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_LATN: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = xfer_rdwr_i ? `PSRAM_FSM_RDATA : `PSRAM_FSM_WDATA;
          s_fsm_cnt_d   = cfg_cflg_i ? 8'd2 : 8'd7;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_WDATA: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_RECY;
          s_fsm_cnt_d   = cfg_recy_i;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;  // NOTE: right?
        end
      end
      `PSRAM_FSM_RDATA: begin  // NOTE: need to capture the posedge of the dqs
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_RECY;
          s_fsm_cnt_d   = cfg_recy_i;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_RECY: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_IDLE;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      default: begin
        s_fsm_state_d = `PSRAM_FSM_IDLE;
        s_fsm_cnt_d   = '0;
      end
    endcase
  end

  dffr #(3) u_fsm_dffr (
      clk_i,
      rst_n_i,
      s_fsm_state_d,
      s_fsm_state_q
  );

  dffr #(8) u_fsm_cnt_dffr (
      clk_i,
      rst_n_i,
      s_fsm_cnt_d,
      s_fsm_cnt_q
  );

endmodule
