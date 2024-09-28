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
`include "edge_det.sv"
`include "clk_int_div.sv"
`include "psram_define.sv"

// inter_clk : psram_clk = 4 : 1
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
    output logic [ 7:0] cfg_data_o,
    input  logic [31:0] bus_addr_i,
    input  logic [63:0] bus_wr_data_i,
    input  logic [ 7:0] bus_wr_mask_i,
    output logic [63:0] bus_rd_data_o,
    input  logic        xfer_valid_i,
    input  logic        xfer_rdwr_i,
    output logic        xfer_ready_o,    // keep many cycles
    output logic        xfer_done_o,     // keep one clk_i cycles
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
  logic [3:0] s_fsm_state_d, s_fsm_state_q;
  logic [7:0] s_fsm_cnt_d, s_fsm_cnt_q, s_div_val;
  logic [7:0] s_wr_shift_data;
  logic       s_wr_shift_mask;
  logic [31:0] s_xfer_addr_d, s_xfer_addr_q;
  logic [63:0] s_wr_data_d, s_wr_data_q;
  logic [7:0] s_wr_mask_d, s_wr_mask_q;
  logic [7:0] s_clk_cnt;
  logic s_ce_fsm_low_bound, s_ce_fsm_high_bound;


  assign xfer_ready_o        = s_fsm_state_q == `PSRAM_FSM_IDLE;
  assign s_ce_fsm_low_bound  = s_fsm_state_q > `PSRAM_FSM_TCSP;
  assign s_ce_fsm_high_bound = s_fsm_state_q < `PSRAM_FSM_TCHD;
  assign psram_sck_o         = s_ce_fsm_low_bound && s_ce_fsm_high_bound ? s_psram_clk : '0;
  // delay one cycle of ce
  assign psram_ce_o          = s_fsm_state_q == `PSRAM_FSM_IDLE || s_fsm_state_q == `PSRAM_FSM_RECY;
  assign psram_io_en_o       = ~(s_fsm_state_q == `PSRAM_FSM_RDATA);  // NOTE: refer to the TRM P16
  assign psram_io_out_o      = s_wr_shift_data;
  assign psram_dqs_en_o      = s_fsm_state_q == `PSRAM_FSM_WDATA;
  assign psram_dqs_out_o     = s_fsm_state_q == `PSRAM_FSM_WDATA ? s_wr_shift_mask : '0;

  always_comb begin
    s_div_val = 8'd3;
    unique case (cfg_pscr_i)
      `PSRAM_PSCR_DIV4:  s_div_val = 8'd3;
      `PSRAM_PSCR_DIV8:  s_div_val = 8'd7;
      `PSRAM_PSCR_DIV16: s_div_val = 8'd15;
      `PSRAM_PSCR_DIV32: s_div_val = 8'd31;
    endcase
  end
  // due to set one-time in init phase, set `div_valid_i` to `0` is ok
  // when div_valid_i == 1, inter cnt reg will set to '0'
  clk_int_div_simple #(
      .DIV_VALUE_WIDTH (8),
      .DONE_DELAY_WIDTH(3)
  ) u_clk_int_div_simple (
      .clk_i      (clk_i),
      .rst_n_i    (rst_n_i),
      .div_i      (s_div_val),
      .div_valid_i(1'b0),
      .div_ready_o(),
      .div_done_o (),
      .clk_cnt_o  (s_clk_cnt),
      .clk_trg_o  (),
      .clk_o      (s_psram_clk)
  );

  // 1. delay some cycles to meet tCSP at negedge of ce
  // 2. align the first posedge of psram_sck when ce == 0
  // 3. delay some cycles to meet tCHD at posedge of ce
  always_comb begin
    s_fsm_state_d = s_fsm_state_q;
    s_fsm_cnt_d   = s_fsm_cnt_q;
    unique case (s_fsm_state_q)
      `PSRAM_FSM_IDLE: begin
        if (xfer_valid_i) begin
          s_fsm_state_d = `PSRAM_FSM_TCSP;
          s_fsm_cnt_d   = 8'd0;
        end
      end
      `PSRAM_FSM_TCSP: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_INST;
          s_fsm_cnt_d   = 8'd2;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_INST: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_ADDR;
          s_fsm_cnt_d   = 8'd4;
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
          s_fsm_state_d = `PSRAM_FSM_TCHD;
          s_fsm_cnt_d   = '0;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_RDATA: begin  // NOTE: need to capture the posedge of the dqs
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `PSRAM_FSM_TCHD;
          s_fsm_cnt_d   = '0;
        end else begin
          s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `PSRAM_FSM_TCHD: begin
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

  // HACK: chg data at 0 or 2 for div4 when ce == 0
  // when in INST, ADDR or xDATA phase, ddr mode
  // otherwise in sdr mode
  always_comb begin
    if (s_fsm_state_q == `PSRAM_FSM_IDLE) begin
      s_psram_clk_trg = 1'b1;
    end else if (s_fsm_state_q == `PSRAM_FSM_INST  || s_fsm_state_q == `PSRAM_FSM_ADDR ||
        s_fsm_state_q == `PSRAM_FSM_WDATA || s_fsm_state_q == `PSRAM_FSM_RDATA) begin
      s_psram_clk_trg = s_clk_cnt == 0 || s_clk_cnt == 2;
    end else begin
      s_psram_clk_trg = s_clk_cnt == 3;
    end
  end
  dffer #(4) u_fsm_state_dffer (
      clk_i,
      rst_n_i,
      s_psram_clk_trg,
      s_fsm_state_d,
      s_fsm_state_q
  );

  dffer #(8) u_fsm_cnt_dffer (
      clk_i,
      rst_n_i,
      s_psram_clk_trg,
      s_fsm_cnt_d,
      s_fsm_cnt_q
  );

  always_comb begin
    s_wr_shift_data = '0;
    s_wr_shift_mask = '0;
    unique case (s_fsm_state_q)
      `PSRAM_FSM_IDLE:  s_wr_shift_data = '0;
      `PSRAM_FSM_INST: begin
        s_wr_shift_data = cfg_cflg_i ? cfg_ccmd_i : (xfer_rdwr_i ? cfg_rcmd_i : cfg_wcmd_i);
      end
      `PSRAM_FSM_ADDR:  s_wr_shift_data = s_xfer_addr_q[31:24];
      `PSRAM_FSM_LATN:  s_wr_shift_data = '0;
      `PSRAM_FSM_WDATA: begin
        s_wr_shift_data = s_wr_data_q[63:56];
        s_wr_shift_mask = s_wr_mask_q[7];
      end
      `PSRAM_FSM_RDATA: s_wr_shift_data = '0;
      `PSRAM_FSM_RECY:  s_wr_shift_data = '0;
      default:          s_wr_shift_data = '0;
    endcase
  end

  // addr shift reg
  always_comb begin
    if (s_fsm_state_q == `PSRAM_FSM_ADDR) s_xfer_addr_d = {s_xfer_addr_q[23:0], 8'd0};
    else s_xfer_addr_d = cfg_cflg_i ? cfg_addr_i : bus_addr_i;
  end
  dffer #(32) u_xfer_addr_dffer (
      clk_i,
      rst_n_i,
      s_psram_clk_trg,
      s_xfer_addr_d,
      s_xfer_addr_q
  );

  // wr data shift reg
  always_comb begin
    if (s_fsm_state_q == `PSRAM_FSM_WDATA) s_wr_data_d = {s_wr_data_q[55:0], 8'd0};
    else s_wr_data_d = cfg_cflg_i ? {cfg_data_i, 56'd0} : bus_wr_data_i;
  end
  dffer #(64) u_wr_data_dffer (
      clk_i,
      rst_n_i,
      s_psram_clk_trg,
      s_wr_data_d,
      s_wr_data_q
  );

  // wr mask shift reg
  always_comb begin
    if (s_fsm_state_q == `PSRAM_FSM_WDATA) s_wr_mask_d = {s_wr_mask_q[6:0], 1'b0};
    else s_wr_mask_d = cfg_cflg_i ? '1 : bus_wr_mask_i;
  end
  dffer #(8) u_wr_mask_dffer (
      clk_i,
      rst_n_i,
      s_psram_clk_trg,
      s_wr_mask_d,
      s_wr_mask_q
  );


  edge_det_sync_re u_xfer_done_edge_det_sync_re (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (xfer_ready_o),
      .re_o   (xfer_done_o)
  );

endmodule
