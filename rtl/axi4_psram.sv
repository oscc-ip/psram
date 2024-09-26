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
    parameter int USR_ADDR_SIZE = 64 * 1024 * 1024  // 64MB
) (
    apb4_if.slave apb4,
    axi4_if.slave axi4,
    psram_if.dut  psram
);

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`PSRAM_CTRL_WIDTH-1:0] s_psram_ctrl_d, s_psram_ctrl_q;
  logic s_psram_ctrl_en;
  logic [`PSRAM_CMD_WIDTH-1:0] s_psram_cmd_d, s_psram_cmd_q;
  logic s_psram_cmd_en;
  logic [`PSRAM_CCMD_WIDTH-1:0] s_psram_ccmd_d, s_psram_ccmd_q;
  logic s_psram_ccmd_en;
  logic [`PSRAM_WAIT_WIDTH-1:0] s_psram_wait_d, s_psram_wait_q;
  logic s_psram_wait_en;
  logic [`PSRAM_ADDR_WIDTH-1:0] s_psram_addr_d, s_psram_addr_q;
  logic s_psram_addr_en;
  logic [`PSRAM_DATA_WIDTH-1:0] s_psram_data_d, s_psram_data_q;
  logic s_psram_data_en;
  logic [`PSRAM_STAT_WIDTH-1:0] s_psram_stat_d, s_psram_stat_q;
  // bitfield
  logic s_bit_en, s_bit_cflg, s_bit_done;
  logic [1:0] s_bit_pscr, s_bit_crm;
  logic [7:0] s_bit_recy, s_bit_wcmd, s_bit_rcmd, s_bit_ccmd;
  logic [7:0] s_bit_wlc, s_bit_rlc;
  // other
  logic s_xfer_valid_d, s_xfer_valid_q;
  logic s_xfer_rdwr_d, s_xfer_rdwr_q, s_xfer_ready;
  logic [7:0] s_cfg_rd_data;


  assign s_bit_en        = s_psram_ctrl_q[0];
  assign s_bit_cflg      = s_psram_ctrl_q[1];
  assign s_bit_pscr      = s_psram_ctrl_q[3:2];
  assign s_bit_recy      = s_psram_ctrl_q[11:4];
  assign s_bit_wcmd      = s_psram_cmd_q[7:0];
  assign s_bit_rcmd      = s_psram_cmd_q[15:8];
  assign s_bit_ccmd      = s_psram_ccmd_q[7:0];
  assign s_bit_wlc       = s_psram_wait_q[7:0];
  assign s_bit_rlc       = s_psram_wait_q[15:8];
  assign s_bit_crm       = s_psram_stat_q[1:0];
  assign s_bit_done      = s_psram_stat_q[2];

  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  // irq
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

  assign s_psram_cmd_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_CMD && s_bit_cflg;
  assign s_psram_cmd_d  = apb4.pwdata[`PSRAM_CMD_WIDTH-1:0];
  dffer #(`PSRAM_CMD_WIDTH) u_psram_cmd_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_cmd_en,
      s_psram_cmd_d,
      s_psram_cmd_q
  );

  assign s_psram_ccmd_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_CCMD && s_bit_cflg;
  assign s_psram_ccmd_d  = apb4.pwdata[`PSRAM_CCMD_WIDTH-1:0];
  dffer #(`PSRAM_CCMD_WIDTH) u_psram_ccmd_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_ccmd_en,
      s_psram_ccmd_d,
      s_psram_ccmd_q
  );

  assign s_psram_wait_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_WAIT && s_bit_cflg;
  assign s_psram_wait_d  = apb4.pwdata[`PSRAM_WAIT_WIDTH-1:0];
  dffer #(`PSRAM_WAIT_WIDTH) u_psram_wait_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_wait_en,
      s_psram_wait_d,
      s_psram_wait_q
  );

  assign s_psram_addr_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_ADDR && s_bit_cflg;
  assign s_psram_addr_d  = apb4.pwdata[`PSRAM_ADDR_WIDTH-1:0];
  dffer #(`PSRAM_ADDR_WIDTH) u_psram_addr_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_addr_en,
      s_psram_addr_d,
      s_psram_addr_q
  );


  assign s_psram_data_en = s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_DATA && s_bit_cflg;
  always_comb begin
    if (s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_DATA && s_bit_cflg) begin
      s_psram_data_d = apb4.pwdata[`PSRAM_DATA_WIDTH-1:0];
    end else if (s_bit_cflg) begin
      s_psram_data_d = s_cfg_rd_data;
    end
  end
  dffer #(`PSRAM_DATA_WIDTH) u_psram_data_dffer (
      apb4.pclk,
      apb4.presetn,
      s_psram_data_en,
      s_psram_data_d,
      s_psram_data_q
  );


  assign s_psram_stat_d[2]   = s_xfer_ready;
  assign s_psram_stat_d[1:0] = `PSRAM_MODE_OPI;
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
        `PSRAM_CMD:  apb4.prdata[`PSRAM_CMD_WIDTH-1:0] = s_psram_cmd_q;
        `PSRAM_CCMD: apb4.prdata[`PSRAM_CCMD_WIDTH-1:0] = s_psram_ccmd_q;
        `PSRAM_WAIT: apb4.prdata[`PSRAM_WAIT_WIDTH-1:0] = s_psram_wait_q;
        `PSRAM_ADDR: apb4.prdata[`PSRAM_ADDR_WIDTH-1:0] = s_psram_addr_q;
        `PSRAM_DATA: apb4.prdata[`PSRAM_DATA_WIDTH-1:0] = s_psram_data_q;
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
      .s_usr_bm_o     (),
      .s_usr_dat_o    (),
      .s_usr_dat_i    ('0),
      .s_usr_awready_i('0),
      .s_usr_wready_i ('0),
      .s_usr_bvalid_i ('0),
      .s_usr_arready_i('0),
      .s_usr_rvalid_i ('0)
  );




  // TODO: add cfg rd oper and axi4 wr/rd oper
  always_comb begin
    s_xfer_valid_d = s_xfer_valid_q;
    if (s_bit_cflg && ~s_xfer_valid_q) begin
      s_xfer_valid_d = (s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_DATA);
    end
  end
  dffr #(1) u_xfer_valid_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_xfer_valid_d,
      s_xfer_valid_q
  );

  // TODO: add axi4 wr/rd oper
  always_comb begin
    s_xfer_rdwr_d = s_xfer_rdwr_q;
    if (s_bit_cflg && ~s_xfer_rdwr_q) begin  // HACK:
      s_xfer_rdwr_d = ~(s_apb4_wr_hdshk && s_apb4_addr == `PSRAM_DATA);
    end
  end
  dffr #(1) u_xfer_rdwr_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_xfer_rdwr_d,
      s_xfer_rdwr_q
  );
  psram_core u_psram_core (
      .clk_i          (axi4.aclk),
      .rst_n_i        (axi4.aresetn),
      .cfg_cflg_i     (s_bit_cflg),
      .cfg_pscr_i     (s_bit_pscr),
      .cfg_recy_i     (s_bit_recy),
      .cfg_wcmd_i     (s_bit_wcmd),
      .cfg_rcmd_i     (s_bit_rcmd),
      .cfg_ccmd_i     (s_bit_ccmd),
      .cfg_wlc_i      (s_bit_wlc),
      .cfg_rlc_i      (s_bit_rlc),
      .cfg_addr_i     (s_psram_addr_q),
      .cfg_data_i     (s_psram_data_q),
      .cfg_data_o     (s_cfg_rd_data),
      .bus_addr_i     ('0),
      .bus_wr_data_i  ('0),
      .bus_wr_mask_i  ('1),
      .bus_rd_data_o  (),
      .xfer_valid_i   (s_xfer_valid_q),        // last for div clk
      .xfer_rdwr_i    ('0),                    // last for div clks_xfer_rdwr_q
      .xfer_ready_o   (s_xfer_ready),
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
