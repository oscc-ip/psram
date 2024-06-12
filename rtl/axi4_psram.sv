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

module axi4_psram (
    apb4_if.slave apb4,
    // axi4_if.master axi4,
    psram_if.dut  psram
);

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
  logic s_psram_stat_en;

  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

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

  always_comb begin
    apb4.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `PSRAM_CTRL: apb4.prdata[`PSRAM_CTRL_WIDTH-1:0] = s_psram_ctrl_q;
        `PSRAM_PSCR: apb4.prdata[`PSRAM_PSCR_WIDTH-1:0] = s_psram_pscr_q;
        `PSRAM_CMD:  apb4.prdata[`PSRAM_CMD_WIDTH-1:0] = s_psram_cmd_q;
        `PSRAM_WAIT: apb4.prdata[`PSRAM_WAIT_WIDTH-1:0] = s_psram_wait_q;
        `PSRAM_CFG:  apb4.prdata[`PSRAM_CFG_WIDTH-1:0] = s_psram_cfg_q;
        default:     apb4.prdata = '0;
      endcase
    end
  end

  psram_core u_psram_core (
      .clk_i         (apb4.pclk),
      .rst_n_i       (apb4.presetn),         // TODO:
      .pscr_i        (s_psram_pscr_q),
      .start_i       (1'b1),
      .done_o        (),
      .psram_sck_o   (psram.psram_sck_o),
      .psram_ce_o    (psram.psram_ce_o),
      .psram_io_en_o (psram.psram_io_en_o),
      .psram_io_in_i (psram.psram_io_in_i),
      .psram_io_out_o(psram.psram_io_out_o)
  );
endmodule
