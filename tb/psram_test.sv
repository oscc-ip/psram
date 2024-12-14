// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// psram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_PSRAM_TEST_SV
`define INC_PSRAM_TEST_SV

`include "apb4_axi4_master.sv"
`include "psram_define.sv"

class PSRAMTest extends APB4AXI4Master;
  string              name;
  virtual psram_if.tb psram;

  extern function new(string name = "psram_test", virtual apb4_if.master apb4,
                      virtual axi4_if.master axi4, virtual psram_if.tb psram);
  extern task automatic test_reset_reg();
  extern task automatic test_wr_rd_reg(input bit [31:0] run_times = 1000);
  extern task automatic init_common_cfg(bit cfg_mode, bit cfg_wr, bit global_reset = 1'b0);
  extern task automatic wait_xfer_done();
  extern task automatic psram_init_device();
  extern task automatic psram_global_reset();
  extern task automatic psram_cfg_wr(input bit [7:0] addr, input bit [7:0] data);
  extern task automatic psram_cfg_rd(input bit [7:0] addr);
  extern task automatic test_cfg_reg();
  extern task automatic test_bus_wr_rd();
  extern task automatic test_bus_random_wr_rd();
endclass

function PSRAMTest::new(string name, virtual apb4_if.master apb4, virtual axi4_if.master axi4,
                        virtual psram_if.tb psram);
  super.new("apb4_axi4_master", apb4, axi4);
  this.name  = name;
  this.psram = psram;
endfunction

task automatic PSRAMTest::test_reset_reg();
  // verilog_format: off
  this.apb4_rd_check(`PSRAM_CTRL_ADDR, "CTRL REG", 32'd0 & {`PSRAM_CTRL_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.apb4_rd_check(`PSRAM_CMD_ADDR,  "CMD REG",  32'd0 & {`PSRAM_CMD_WIDTH{1'b1}},  Helper::EQUL, Helper::INFO);
  this.apb4_rd_check(`PSRAM_CCMD_ADDR, "CCMD REG", 32'd0 & {`PSRAM_CCMD_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.apb4_rd_check(`PSRAM_WAIT_ADDR, "WAIT REG", 32'd0 & {`PSRAM_WAIT_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.apb4_rd_check(`PSRAM_ADDR_ADDR, "ADDR REG", 32'd0 & {`PSRAM_ADDR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  // verilog_format: on
endtask

task automatic PSRAMTest::test_wr_rd_reg(input bit [31:0] run_times = 1000);
  // verilog_format: off
  for (int i = 0; i < run_times; i++) begin
    this.apb4_wr_rd_check(`PSRAM_CTRL_ADDR, "CTRL REG", $random & {`PSRAM_CTRL_WIDTH{1'b1}}, Helper::EQUL);
    this.apb4_write(`PSRAM_CTRL_ADDR, '1);
    this.apb4_wr_rd_check(`PSRAM_CMD_ADDR,  "CMD REG",  $random & {`PSRAM_CMD_WIDTH{1'b1}},  Helper::EQUL);
    this.apb4_wr_rd_check(`PSRAM_CCMD_ADDR, "CCMD REG", $random & {`PSRAM_CCMD_WIDTH{1'b1}}, Helper::EQUL);
    this.apb4_wr_rd_check(`PSRAM_WAIT_ADDR, "WAIT REG", $random & {`PSRAM_WAIT_WIDTH{1'b1}}, Helper::EQUL);
    this.apb4_wr_rd_check(`PSRAM_ADDR_ADDR, "ADDR REG", $random & {`PSRAM_ADDR_WIDTH{1'b1}}, Helper::EQUL);
  end
  // verilog_format: on
endtask

task automatic PSRAMTest::init_common_cfg(bit cfg_mode, bit cfg_wr, bit global_reset = 1'b0);
  bit [31:0] ctrl_val = '0, cmd_val = '0, ccmd_val = '0;
  bit [31:0] wait_val = '0;
  // wr cmd
  this.apb4_write(`PSRAM_CTRL_ADDR, ctrl_val);
  ctrl_val[1]     = cfg_mode;
  ctrl_val[3:2]   = 2'd1;  // div8
  ctrl_val[11:4]  = 8'd13;  // delay 3 cycle
  ctrl_val[13:12] = 2'd1;  // tcsp
  ctrl_val[15:14] = 2'd1;  // tchd
  ctrl_val[17:16] = 2'd1;  // div8
  this.apb4_write(`PSRAM_CTRL_ADDR, ctrl_val);
  cmd_val[7:0]  = 8'hA0;  // wcmd 8'hA0
  cmd_val[15:8] = 8'h20;  // rcmd 8'h20
  this.apb4_write(`PSRAM_CMD_ADDR, cmd_val);

  if (global_reset) ccmd_val[7:0] = 8'hFF;
  else if (cfg_wr) ccmd_val[7:0] = 8'hC0;
  else ccmd_val[7:0] = 8'h40;

  this.apb4_write(`PSRAM_CCMD_ADDR, ccmd_val);
  wait_val[7:0]  = 8'd5 - 8'd1;
  wait_val[15:8] = 8'd5 - 8'd1;
  this.apb4_write(`PSRAM_WAIT_ADDR, wait_val);
  ctrl_val[0] = 1'b1;  // en core clk
  this.apb4_write(`PSRAM_CTRL_ADDR, ctrl_val);
  $display("CTRL: %h CMD: %h CCMD: %h WAIT: %h", ctrl_val, cmd_val, ccmd_val, wait_val);
endtask

task automatic PSRAMTest::psram_init_device();
  $display("%t === [init psram init device] ===", $time);
  // for 800M clock, need delay >= 150us, 150 * 1000 / 1.25 = 60000 * 2
  for (int i = 0; i < 120000 / 400; i++) begin
    repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  end
endtask

task automatic PSRAMTest::psram_global_reset();
  repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  $display("%t === [test psram global reset] ===", $time);
  this.init_common_cfg(1'b1, 1'b0, 1'b1);

  this.apb4_write(`PSRAM_ADDR_ADDR, 32'd0);
  this.apb4_write(`PSRAM_DATA_ADDR, 32'd0);

  //2000/1.25 = 1600
  repeat (2000) @(posedge this.apb4_mstr.apb4.pclk);  // delay >= 2us=2000ns
endtask

task automatic PSRAMTest::psram_cfg_wr(input bit [7:0] addr, input bit [7:0] data);
  // repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  // $display("%t === [test psram cfg wr] ===", $time);

  this.apb4_write(`PSRAM_ADDR_ADDR, {24'd0, addr});
  this.apb4_write(`PSRAM_DATA_ADDR, data);
  repeat (100) @(posedge this.apb4_mstr.apb4.pclk);
endtask

task automatic PSRAMTest::psram_cfg_rd(input bit [7:0] addr);
  // repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  // $display("%t === [test psram cfg rd] ===", $time);
  repeat (50) @(posedge this.apb4_mstr.apb4.pclk);
  this.apb4_write(`PSRAM_ADDR_ADDR, {24'd0, addr});
  this.apb4_read(`PSRAM_DATA_ADDR);
endtask

task automatic PSRAMTest::wait_xfer_done();
  do begin
    this.apb4_read(`PSRAM_STAT_ADDR);
  end while (this.apb4_mstr.rd_data[2] == 1'b0);
endtask

task automatic PSRAMTest::test_cfg_reg();
  $display("%t === [test cfg reg] ===", $time);
  this.init_common_cfg(1'b1, 1'b0);
  for (int i = 0; i < 9; i++) begin
    if (i == 5 || i == 6 || i == 7) continue;
    this.psram_cfg_rd(i);
    this.wait_xfer_done();
    this.apb4_read(`PSRAM_RDAT_ADDR);
    $display("addr: %d data: %b", i, this.apb4_mstr.rd_data[7:0]);
  end

  // $display("wr reg 0");
  // this.init_common_cfg(1'b1, 1'b1);
  // this.psram_cfg_wr(8'h0, 8'b00_0_010_10);
  // this.wait_xfer_done();

  // this.init_common_cfg(1'b1, 1'b0);
  // this.psram_cfg_rd(8'h0);
  // this.wait_xfer_done();
  // $display("[modify]addr: 0 data: %b", recv[0]);

  // this.init_common_cfg(1'b1, 1'b1);
  // this.psram_cfg_wr(8'h0, 8'b00_0_010_01);
  // this.wait_xfer_done();

  // this.init_common_cfg(1'b1, 1'b0);
  // this.psram_cfg_rd(8'h0, recv);
  // this.wait_xfer_done();
  // $display("[modify]addr: 0 data: %b", recv[0]);
endtask

task automatic PSRAMTest::test_bus_wr_rd();
  bit [`AXI4_DATA_WIDTH-1:0] trans_wdata [$];
  bit [`AXI4_ADDR_WIDTH-1:0] trans_addr;
  bit [`AXI4_ADDR_WIDTH-1:0] trans_baddr;
  bit [                 2:0] trans_size;
  bit [                 1:0] trans_type;
  int                        trans_len;
  bit [`AXI4_DATA_WIDTH-1:0] trans_val;
  int                        trans_id;

  repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  $display("%t === [test psram bus wr rd] ===", $time);
  this.init_common_cfg(1'b1, 1'b1);
  this.init_common_cfg(1'b0, 1'b1);

  trans_wdata = {};
  trans_baddr = 32'hE000_0000;  // test 0x000-0x7FF
  // trans_addr  = trans_baddr + 8 * 2;
  // E000_0000 + 0001_0310 = E001_0310
  // trans_addr  = trans_baddr + 32'h0001_0310;
  trans_size  = 3'd3;
  trans_type  = `AXI4_BURST_TYPE_INCR;
  trans_len   = 8'd2;
  trans_id    = '1;
  for (int i = 0; i < trans_len + 1; i++) begin
    trans_val = {$random, $random};
    $display("%d: wr_val: %0h", i, trans_val);
    trans_wdata.push_back(trans_val);
  end

  this.axi4_write(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                  .burst(trans_type), .data(trans_wdata));
  repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  $display("write data done");
  this.wait_xfer_done();
  $display("start read data");
  this.axi4_read(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                 .burst(trans_type));

  for (int i = 0; i < trans_len + 1; i++) begin
    if (trans_wdata[i] != this.axi4_mstr.rd_data[i]) begin
      $display("i: %d wr_data: %h rd_data: %h", i, trans_wdata[i], this.axi4_mstr.rd_data[i]);
    end
  end
  $display("trans_len: %d simple smoke test done", trans_len);
endtask


task automatic PSRAMTest::test_bus_random_wr_rd();

  bit [`AXI4_DATA_WIDTH-1:0] trans_wdata [$];
  bit [`AXI4_ADDR_WIDTH-1:0] trans_addr;
  bit [`AXI4_ADDR_WIDTH-1:0] trans_baddr;
  bit [                 2:0] trans_size;
  bit [                 1:0] trans_type;
  int                        trans_len;
  int                        trans_id;

  $display("%t random burst wr/rd test", $time);
  for (int i = 0; i < 10000; i++) begin
    trans_len   = {$random} % 256;
    trans_id    = {$random} % 16;
    trans_size  = {$random} % 4;
    // trans_type  = {$random} % 2;
    trans_type  = `AXI4_BURST_TYPE_INCR;
    // 32'hE000_0000 - 32'hE400_0000(range: 64MB)
    trans_baddr = 32'hE000_0000;
    // generate aligned addr
    trans_addr  = trans_baddr + ((({$random} % 32'h03FF_FFF8) >> trans_size) << trans_size);
    $display("i: %d id: %d addr: %h len: %d size: %h burst: %d", i, trans_id, trans_addr,
             trans_len, trans_size, trans_type);
    trans_wdata = {};
    for (int j = 0; j < trans_len; j++) begin
      trans_wdata.push_back({$random, $random});
    end

    if (trans_type == `AXI4_BURST_TYPE_FIXED) begin
      trans_len = 1;
    end
    this.axi4_write(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                    .burst(trans_type), .data(trans_wdata));

    repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
    // $display("write data done");
    this.wait_xfer_done();

    this.axi4_rd_check(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                       .burst(trans_type), .ref_data(trans_wdata), .cmp_type(Helper::EQUL));
  end

endtask

`endif
