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

// clk_i/psram_sck_o = 4
module psram_core (
    input  logic                         clk_i,
    input  logic                         rst_n_i,
    input  logic                         en_i,
    input  logic                         cflg_i,
    input  logic [                  7:0] ma_i,
    input  logic [`PSRAM_PSCR_WIDTH-1:0] pscr_i,
    input  logic [                  7:0] wrc_i,
    input  logic [                  7:0] rdc_i,
    input  logic [                  7:0] wrw_i,
    input  logic [                  7:0] rdw_i,
    input  logic [                  7:0] wrf_i,
    input  logic [                  7:0] rdf_i,
    input  logic                         cfg_wr_i,
    input  logic                         cfg_rd_i,
    input  logic [                  7:0] cfg_data_i,
    input  logic [                  7:0] cfg_data_o,
    output logic [                  1:0] crm_o,
    output logic                         done_o,
    output logic                         psram_sck_o,
    output logic                         psram_ce_o,
    output logic [                  7:0] psram_io_en_o,
    input  logic [                  7:0] psram_io_in_i,
    output logic [                  7:0] psram_io_out_o,
    output logic                         psram_dqs_en_o,
    input  logic                         psram_dqs_in_i,
    output logic                         psram_dqs_out_o
);

  logic s_fsm_d, s_fsm_q;
  logic s_ce_d, s_ce_q, s_sck_d, s_sck_q;
  logic [7:0] s_pscr_cnt_d, s_pscr_cnt_q;
  //
  logic s_start_trans, s_cmd_addr_done;
  logic [1:0] s_cmd_fsm_d, s_cmd_fsm_q;
  logic [7:0] s_wr_wait, s_rd_wait, s_trans_cnt_d, s_trans_cnt_q, s_trans_limit_d, s_trans_limit_q;
  logic [55:0] s_cmd_addr;

  assign crm_o         = `PSRAM_MODE_OPI;  // only support OPI mode now
  assign psram_ce_o    = s_ce_q;
  assign psram_sck_o   = s_sck_q;

  assign s_start_trans = cflg_i && (cfg_wr_i | cfg_rd_i);  // TODO: for axi4 wr/rd

  always_comb begin
    s_cmd_fsm_d = s_cmd_fsm_q;
    if (cfg_wr_i) s_cmd_fsm_d = `PSRAM_CMD_WR;
    else if (cfg_rd_i) s_cmd_fsm_d = `PSRAM_CMD_RD;
    else if (done_o) s_cmd_fsm_d = `PSRAM_CMD_IDLE;
  end
  dffr #(2) u_cmd_fsm_dffr (
      clk_i,
      rst_n_i,
      s_cmd_fsm_d,
      s_cmd_fsm_q
  );

  always_comb begin
    s_fsm_d = s_fsm_q;
    unique case (s_fsm_q)
      `PSRAM_FSM_IDLE: if (en_i && s_start_trans) s_fsm_d = `PSRAM_FSM_BUSY;
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
  dffrh #(1) u_ce_dffrh (
      clk_i,
      rst_n_i,
      s_ce_d,
      s_ce_q
  );

  always_comb begin
    s_pscr_cnt_d = '0;
    if (~s_ce_q) begin
      if (s_pscr_cnt_q == '0) s_pscr_cnt_d = pscr_i;
      else s_pscr_cnt_d = s_pscr_cnt_q - 1'b1;
    end
  end
  dffr #(`PSRAM_PSCR_WIDTH) u_pscr_cnt_dffr (
      clk_i,
      rst_n_i,
      s_pscr_cnt_d,
      s_pscr_cnt_q
  );

  always_comb begin
    s_sck_d = s_sck_q;
    if (done_o) s_sck_d = 1'b0;
    else if (~s_ce_q && s_pscr_cnt_q == '0) s_sck_d = ~s_sck_q;
  end
  dffr #(1) u_sck_dffr (
      clk_i,
      rst_n_i,
      s_sck_d,
      s_sck_q
  );

  assign s_wr_wait = cflg_i ? 8'd2 : '0;
  assign s_rd_wait = cflg_i ? rdw_i * 2 : '0;  // NOTE: maybe not no need

  // cmd-8b addr-32b 
  always_comb begin
    s_cmd_addr = '0;
    if (cflg_i) begin
      if (cfg_wr_i) s_cmd_addr = {wrf_i, wrf_i, 24'd0, ma_i, cfg_data_i};
      else if (cfg_rd_i) s_cmd_addr = {rdf_i, rdf_i, 24'd0, ma_i, 8'd0};
    end
  end

  // dq dqm
  // TODO: for normal wr rd oper
  always_comb begin
    psram_io_en_o   = '0;
    psram_dqs_en_o  = '0;
    psram_dqs_out_o = '0;
    if (cfg_wr_i || s_cmd_fsm_q == `PSRAM_CMD_WR) begin
      psram_io_en_o  = '1;
      psram_dqs_en_o = '1;
    end else if (cfg_rd_i || s_cmd_fsm_q == `PSRAM_CMD_RD) begin
      psram_dqs_en_o = '0;
      if (s_cmd_addr_done) psram_io_en_o = '1;
      else psram_io_en_o = '0;
    end
  end

  shift_reg #(
      .DATA_WIDTH(56),
      .SHIFT_NUM (8)
  ) u_psram_tx_shift_reg (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .type_i    (`SHIFT_REG_TYPE_LOGIC),
      .dir_i     ('0),
      .ld_en_i   (cfg_wr_i | cfg_rd_i),
      .sft_en_i  ((~s_ce_q) & (s_pscr_cnt_q == 8'd1)),
      .ser_dat_i ('0),
      .par_data_i(s_cmd_addr),
      .ser_dat_o (psram_io_out_o),
      .par_data_o()
  );

  assign s_cmd_addr_done = s_trans_cnt_q == 8'd6;  // HACK:
  assign done_o          = s_trans_cnt_q == s_trans_limit_q;
  always_comb begin
    s_trans_limit_d = s_trans_limit_q;
    if (cflg_i) begin
      if (cfg_wr_i) s_trans_limit_d = 8'd6 + s_wr_wait;
      else if (cfg_rd_i) s_trans_limit_d = 8'd6 + s_rd_wait;
    end
  end
  dffr #(8) u_trans_limit_dffr (
      clk_i,
      rst_n_i,
      s_trans_limit_d,
      s_trans_limit_q
  );

  always_comb begin
    s_trans_cnt_d = s_trans_cnt_q;
    if (s_trans_cnt_q == s_trans_limit_q) s_trans_cnt_d = '0;
    else s_trans_cnt_d = s_trans_cnt_q + 1'b1;
  end
  dffer #(8) u_trans_cnt_dffer (
      clk_i,
      rst_n_i,
      (~s_ce_q) & (s_pscr_cnt_q == 8'd1),
      s_trans_cnt_d,
      s_trans_cnt_q
  );

endmodule
