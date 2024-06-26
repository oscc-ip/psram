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
`include "axi4_define.sv"
`include "axi4_slv_fsm.sv"
`include "psram_define.sv"

module axi4_psram #(
    parameter int USR_ADDR_SIZE = 64 * 1024 * 1024
) (
    apb4_if.slave apb4,
    axi4_if.slave axi4,
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

  // bitfield
  logic s_bit_en, s_bit_cflg;
  logic [7:0] s_bit_ma;
  logic [7:0] s_bit_wrc, s_bit_rdc;
  logic [7:0] s_bit_wrw, s_bit_rdw;
  logic [7:0] s_bit_wrf, s_bit_rdf;
  // other
  logic       s_done;
  logic [1:0] s_crm;
  logic [7:0] s_cfg_rd_data;

  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  assign s_bit_en        = s_psram_ctrl_q[0];
  assign s_bit_cflg      = s_psram_ctrl_q[1];
  assign s_bit_ma        = s_psram_ctrl_q[9:2];
  assign s_bit_wrc       = s_psram_cmd_q[7:0];
  assign s_bit_rdc       = s_psram_cmd_q[15:8];
  assign s_bit_wrw       = s_psram_wait_q[7:0];
  assign s_bit_rdw       = s_psram_wait_q[15:8];
  assign s_bit_wrf       = s_psram_cfg_q[7:0];
  assign s_bit_rdf       = s_psram_cfg_q[15:8];

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

  assign s_psram_stat_d[2]   = s_done;
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
        `PSRAM_DATA: apb4.prdata[`PSRAM_DATA_WIDTH-1:0] = s_cfg_rd_data;
        `PSRAM_STAT: apb4.prdata[`PSRAM_STAT_WIDTH-1:0] = s_psram_stat_q;
        default:     apb4.prdata = '0;
      endcase
    end
  end

  axi4_slv_fsm #(
      .USR_ADDR_SIZE(USR_ADDR_SIZE)
  ) u_axi4_slv_fsm (
      .aclk           (axi4.aclk),
      .aresetn        (axi4.aresetn),
      .awid           (axi4.awid),
      .awaddr         (axi4.awaddr),
      .awlen          (axi4.awlen),
      .awsize         (axi4.awsize),
      .awburst        (axi4.awburst),
      .awlock         (axi4.awlock),
      .awcache        (axi4.awcache),
      .awprot         (axi4.awprot),
      .awqos          (axi4.awqos),
      .awregion       (axi4.awregion),
      .awuser         (axi4.awuser),
      .awvalid        (axi4.awvalid),
      .awready        (axi4.awready),
      .wdata          (axi4.wdata),
      .wstrb          (axi4.wstrb),
      .wlast          (axi4.wlast),
      .wuser          (axi4.wuser),
      .wvalid         (axi4.wvalid),
      .wready         (axi4.wready),
      .bid            (axi4.bid),
      .bresp          (axi4.bresp),
      .buser          (axi4.buser),
      .bvalid         (axi4.bvalid),
      .bready         (axi4.bready),
      .arid           (axi4.arid),
      .araddr         (axi4.araddr),
      .arlen          (axi4.arlen),
      .arsize         (axi4.arsize),
      .arburst        (axi4.arburst),
      .arlock         (axi4.arlock),
      .arcache        (axi4.arcache),
      .arprot         (axi4.arprot),
      .arqos          (axi4.arqos),
      .arregion       (axi4.arregion),
      .aruser         (axi4.aruser),
      .arvalid        (axi4.arvalid),
      .arready        (axi4.arready),
      .rid            (axi4.rid),
      .rdata          (axi4.rdata),
      .rresp          (axi4.rresp),
      .rlast          (axi4.rlast),
      .ruser          (axi4.ruser),
      .rvalid         (axi4.rvalid),
      .rready         (axi4.rready),
      .s_usr_en_o     (),
      .s_usr_wen_o    (),
      .s_usr_addr_o   (),
      .s_usr_bm_i     (),
      .s_usr_dat_i    (),
      .s_usr_awready_i(),
      .s_usr_wready_i (),
      .s_usr_bvalid_i (),
      .s_usr_arready_i(),
      .s_usr_rvalid_i (),
      .s_usr_dat_o    ()
  );

  psram_core u_psram_core (
      .clk_i          (axi4.aclk),
      .rst_n_i        (axi4.aresetn),
      .en_i           (s_bit_en),
      .cflg_i         (s_bit_cflg),
      .ma_i           (s_bit_ma),
      .pscr_i         (s_psram_pscr_q),
      .wrc_i          (s_bit_wrc),
      .rdc_i          (s_bit_rdc),
      .wrw_i          (s_bit_wrw),
      .rdw_i          (s_bit_rdw),
      .wrf_i          (s_bit_wrf),
      .rdf_i          (s_bit_rdf),
      .cfg_wr_i       (s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_DATA),
      .cfg_rd_i       (s_apb4_rd_hdshk && s_apb4_addr == `PSRAM_DATA),
      .cfg_data_i     (apb4.pwdata[7:0]),
      .cfg_data_o     (s_cfg_rd_data),
      .crm_o          (s_crm),
      .done_o         (s_done),
      .psram_sck_o    (psram.psram_sck_o),
      .psram_ce_o     (psram.psram_ce_o),
      .psram_io_en_o  (psram.psram_io_en_o),
      .psram_io_in_i  (psram.psram_io_in_i),
      .psram_io_out_o (psram.psram_io_out_o),
      .psram_dqs_en_o (psram.psram_dqs_en_o),
      .psram_dqs_in_i (psram.psram_dqs_in_i),
      .psram_dqs_out_o(psram.psram_dqs_out_o)
  );
endmodule
