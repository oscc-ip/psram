// Copyright (c) 2023 Beijing Institute of Open Source Chip
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
  extern task automatic init_common_cfg(bit cfg_mode, bit global_reset = 1'b0);
  extern task automatic init_device();
  extern task automatic test_global_reset();
  extern task automatic test_cfg_wr();
  extern task automatic test_cfg_rd();
  extern task automatic test_bus_wr_rd();
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

task automatic PSRAMTest::init_common_cfg(bit cfg_mode, bit global_reset = 1'b0);
  bit [31:0] ctrl_val = '0, cmd_val = '0, ccmd_val = '0;
  bit [31:0] wait_val = '0;
  // wr cmd
  this.apb4_write(`PSRAM_CTRL_ADDR, ctrl_val);
  ctrl_val[1]     = cfg_mode;
  ctrl_val[3:2]   = 2'b01;  // div8
  ctrl_val[11:4]  = 8'd3;  // delay 3 cycle
  ctrl_val[13:12] = 2'd1;  // tcsp
  ctrl_val[15:14] = 2'd1;  // tchd
  this.apb4_write(`PSRAM_CTRL_ADDR, ctrl_val);
  cmd_val[7:0]  = 8'hA0;
  cmd_val[15:8] = 8'h20;
  this.apb4_write(`PSRAM_CMD_ADDR, cmd_val);

  if (global_reset) ccmd_val[7:0] = 8'hFF;
  else ccmd_val[7:0] = 8'hC0;
  this.apb4_write(`PSRAM_CCMD_ADDR, ccmd_val);
  wait_val[7:0]  = 8'd5 - 8'd1;
  wait_val[15:8] = 8'd5 - 8'd1;
  this.apb4_write(`PSRAM_WAIT_ADDR, wait_val);
  ctrl_val[0] = 1'b1;  // en core clk
  this.apb4_write(`PSRAM_CTRL_ADDR, ctrl_val);
endtask

task automatic PSRAMTest::init_device();
  $display("%t === [init psram init device] ===", $time);
  // for 800M clock, need delay >= 150us, 150 * 1000 / 1.25 = 60000 * 2
  for (int i = 0; i < 120000 / 400; i++) begin
    repeat (400) @(posedge this.apb4_mstr.apb4.pclk);
  end
endtask

task automatic PSRAMTest::test_global_reset();
  bit [31:0] addr_val = '0, data_val = '0;
  repeat (400 * 3) @(posedge this.apb4_mstr.apb4.pclk);
  $display("%t === [test psram global reset] ===", $time);
  this.init_common_cfg(1'b1, 1'b1);
  addr_val[7:0] = 8'h00;
  this.apb4_write(`PSRAM_ADDR_ADDR, addr_val);
  data_val[7:0] = 8'b000_00_000;
  this.apb4_write(`PSRAM_DATA_ADDR, data_val);

  repeat (400 * 2) @(posedge this.apb4_mstr.apb4.pclk);
endtask

task automatic PSRAMTest::test_cfg_wr();
  bit [31:0] addr_val = '0, data_val = '0;
  repeat (400 * 3) @(posedge this.apb4_mstr.apb4.pclk);
  $display("%t === [test psram cfg wr] ===", $time);
  this.init_common_cfg(1'b1);

  addr_val[7:0] = 8'h04;
  this.apb4_write(`PSRAM_ADDR_ADDR, addr_val);
  // data_val[7:0] = 8'b00_1_100_00;
  data_val[7:0] = 8'b010_00_000;
  this.apb4_write(`PSRAM_DATA_ADDR, data_val);
  repeat (400 * 2) @(posedge this.apb4_mstr.apb4.pclk);
endtask

task automatic PSRAMTest::test_cfg_rd();
  bit [31:0] addr_val = '0, data_val = '0;
  repeat (400 * 3) @(posedge this.apb4_mstr.apb4.pclk);
  $display("%t === [test psram cfg rd] ===", $time);
  this.init_common_cfg(1'b1);
  repeat (400 * 2) @(posedge this.apb4_mstr.apb4.pclk);
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

  repeat (400 * 3) @(posedge this.apb4_mstr.apb4.pclk);
  $display("%t === [test psram bus wr rd] ===", $time);
  this.init_common_cfg(1'b1);
  this.init_common_cfg(1'b0);

  trans_wdata = {};
  trans_baddr = 32'hE000_0000;  // test 0x000-0x7FF
  // trans_addr  = trans_baddr + 8 * 2;
  // E000_0000 + 0001_0310 = E001_0310
  trans_addr  = trans_baddr + 32'h0001_0310;
  trans_size  = 3'd3;
  trans_type  = `AXI4_BURST_TYPE_INCR;
  trans_len   = 8'd6;
  trans_id    = '1;
  for (int i = 0; i < trans_len; i++) begin
    trans_val = {$random, $random};
    $display("%d: wr_val: %0h", i + 1, trans_val);
    trans_wdata.push_back(trans_val);
  end

  this.axi4_write(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                  .burst(trans_type), .data(trans_wdata));

  repeat (400 * 2) @(posedge this.apb4_mstr.apb4.pclk);
endtask

`endif
