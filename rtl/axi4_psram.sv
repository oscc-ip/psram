// Copyright (c) 2023 Beijing Institute of Open Source Chip
// psram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "register.sv"
`include "fifo.sv"
`include "axi4_define.sv"
`include "psram_define.sv"

module axi4_psram #(
    parameter int FIFO_DEPTH = 32
) (
    apb4_if.slave apb4,
    // axi4_if.master axi4,
    psram_if.dut  psram
);

  localparam int LOG_FIFO_DEPTH = $clog2(FIFO_DEPTH);

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`PSRAM_CTRL_WIDTH-1:0] s_psram_ctrl_d, s_psram_ctrl_q;
  logic s_psram_ctrl_en;
  logic [`PSRAM_PSCR_WIDTH-1:0] s_psram_pscr_d, s_psram_pscr_q;
  logic s_psram_pscr_en;
  logic [`PSRAM_CMD_WIDTH-1:0] s_psram_cmd_d, s_psram_cmd_q;
  logic s_psram_cmd_en;
  logic [`PSRAM_WAIT_WIDTH-1:0] s_psram_wait_d, s_psram_wait_q;
  logic s_psram_wait_en;
  logic [`PSRAM_CFG_WIDTH-1:0] s_psram_cfg_d, s_psram_cfg_q;
  logic s_psram_cfg_en;
  logic [`PSRAM_STAT_WIDTH-1:0] s_psram_stat_d, s_psram_stat_q;

  // bitfield
  logic s_bit_en, s_bit_cflg;
  logic [1:0] s_bit_swm;
  logic [7:0] s_bit_wr_cmd, s_bit_rd_cmd;
  //
  logic s_crm;
  // fifo
  logic s_tx_push_valid, s_tx_push_ready, s_tx_empty, s_tx_full, s_tx_pop_valid, s_tx_pop_ready;
  logic s_rx_push_valid, s_rx_push_ready, s_rx_empty, s_rx_full, s_rx_pop_valid, s_rx_pop_ready;
  logic [63:0] s_tx_push_data, s_tx_pop_data, s_rx_push_data, s_rx_pop_data;
  logic [LOG_FIFO_DEPTH:0] s_tx_elem, s_rx_elem;


  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  assign s_bit_en        = s_psram_ctrl_q[0];
  assign s_bit_cflg      = s_psram_ctrl_q[1];
  assign s_bit_swm       = s_psram_ctrl_q[3:2];
  assign s_bit_wr_cmd    = s_psram_cmd_q[7:0];
  assign s_bit_rd_cmd    = s_psram_cmd_q[15:8];

  assign psram.irq_o     = 0;

  assign s_psram_ctrl_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_CTRL;
  assign s_psram_ctrl_d  = apb4.pwdata[`PSRAM_CTRL_WIDTH-1:0];
  dffer #(`PSRAM_CTRL_WIDTH) u_psram_ctrl_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_ctrl_en,
      s_psram_ctrl_d,
      s_psram_ctrl_q
  );

  assign s_psram_pscr_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_PSCR;
  assign s_psram_pscr_d  = apb4.pwdata[`PSRAM_PSCR_WIDTH-1:0];
  dffer #(`PSRAM_PSCR_WIDTH) u_psram_pscr_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_pscr_en,
      s_psram_pscr_d,
      s_psram_pscr_q
  );

  assign s_psram_cmd_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_CMD;
  assign s_psram_cmd_d  = apb4.pwdata[`PSRAM_CMD_WIDTH-1:0];
  dffer #(`PSRAM_CMD_WIDTH) u_psram_cmd_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_cmd_en,
      s_psram_cmd_d,
      s_psram_cmd_q
  );

  assign s_psram_wait_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_WAIT;
  assign s_psram_wait_d  = apb4.pwdata[`PSRAM_WAIT_WIDTH-1:0];
  dffer #(`PSRAM_WAIT_WIDTH) u_psram_wait_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_wait_en,
      s_psram_wait_d,
      s_psram_wait_q
  );

  assign s_psram_cfg_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_CFG;
  assign s_psram_cfg_d  = apb4.pwdata[`PSRAM_CFG_WIDTH-1:0];
  dffer #(`PSRAM_CFG_WIDTH) u_psram_cfg_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_cfg_en,
      s_psram_cfg_d,
      s_psram_cfg_q
  );

  assign s_psram_stat_d[1:0] = s_crm;
  dffr #(`PSRAM_STAT_WIDTH) u_psram_stat_dffr (
      apb4.pclk,
      apb4.presetn,
      s_psram_stat_d,
      s_psram_stat_q
  );

  always_comb begin
    apb4.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `PSRAM_CTRL: apb4.prdata[`PSRAM_CTRL_WIDTH-1:0] = s_psram_ctrl_q;
        `PSRAM_PSCR: apb4.prdata[`PSRAM_PSCR_WIDTH-1:0] = s_psram_pscr_q;
        `PSRAM_CMD:  apb4.prdata[`PSRAM_CMD_WIDTH-1:0] = s_psram_cmd_q;
        `PSRAM_WAIT: apb4.prdata[`PSRAM_WAIT_WIDTH-1:0] = s_psram_wait_q;
        `PSRAM_CFG:  apb4.prdata[`PSRAM_CFG_WIDTH-1:0] = s_psram_cfg_q;
        `PSRAM_STAT: apb4.prdata[`PSRAM_STAT_WIDTH-1:0] = s_psram_stat_q;
        default:     apb4.prdata = '0;
      endcase
    end
  end


  assign s_tx_push_ready = ~s_tx_full;
  assign s_tx_pop_valid  = ~s_tx_empty;
  fifo #(
      .DATA_WIDTH  (64),
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_tx_fifo (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .flush_i(~s_bit_en),
      .cnt_o  (s_tx_elem),
      .push_i (s_tx_push_valid),
      .full_o (s_tx_full),
      .dat_i  (s_tx_push_data),
      .pop_i  (s_tx_pop_ready),
      .empty_o(s_tx_empty),
      .dat_o  (s_tx_pop_data)
  );

  psram_core u_psram_core (
      .clk_i         (apb4.pclk),
      .rst_n_i       (apb4.presetn),         // TODO:
      .en_i          (s_bit_en),
      .cflg_i        (s_bit_cflg),
      .swm_i         (s_bit_swm),
      .crm_o         (s_crm),
      .pscr_i        (s_psram_pscr_q),
      .wr_cmd_i      (s_bit_wr_cmd),
      .rd_cmd_i      (s_bit_rd_cmd),
      .cfg_cmd_i     (s_psram_cfg_q),
      .wait_i        (s_psram_wait_q),
      .tx_valid_i    (s_tx_pop_valid),
      .tx_ready_o    (s_tx_pop_ready),
      .tx_data_i     (s_tx_pop_data),
      .done_o        (),
      .psram_sck_o   (psram.psram_sck_o),
      .psram_ce_o    (psram.psram_ce_o),
      .psram_io_en_o (psram.psram_io_en_o),
      .psram_io_in_i (psram.psram_io_in_i),
      .psram_io_out_o(psram.psram_io_out_o)
  );
endmodule
