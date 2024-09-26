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

`include "apb4_master.sv"
`include "psram_define.sv"

class PSRAMTest extends APB4Master;
  string                 name;
  int                    wr_val;
  int                    ext_pulse_peroid;
  virtual apb4_if.master apb4;
  virtual psram_if.tb    psram;

  extern function new(string name = "psram_test", virtual apb4_if.master apb4,
                      virtual psram_if.tb psram);
  extern task automatic test_reset_reg();
  extern task automatic test_wr_rd_reg(input bit [31:0] run_times = 1000);
  extern task automatic test_cfg_wr_rd();
  extern task automatic test_global_reset();
  extern task automatic test_bus_wr_rd();
endclass

function PSRAMTest::new(string name, virtual apb4_if.master apb4, virtual psram_if.tb psram);
  super.new("apb4_master", apb4);
  this.name  = name;
  this.apb4  = apb4;
  this.psram = psram;
endfunction

task automatic PSRAMTest::test_reset_reg();
  super.test_reset_reg();
  // verilog_format: off
  this.rd_check(`PSRAM_CTRL_ADDR, "CTRL REG", 32'd0 & {`PSRAM_CTRL_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`PSRAM_CMD_ADDR,  "CMD REG",  32'd0 & {`PSRAM_CMD_WIDTH{1'b1}},  Helper::EQUL, Helper::INFO);
  this.rd_check(`PSRAM_CCMD_ADDR, "CCMD REG", 32'd0 & {`PSRAM_CCMD_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`PSRAM_WAIT_ADDR, "WAIT REG", 32'd0 & {`PSRAM_WAIT_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`PSRAM_ADDR_ADDR, "ADDR REG", 32'd0 & {`PSRAM_ADDR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  // verilog_format: on
endtask

task automatic PSRAMTest::test_wr_rd_reg(input bit [31:0] run_times = 1000);
  super.test_wr_rd_reg();
  // verilog_format: off
  for (int i = 0; i < run_times; i++) begin
    this.wr_rd_check(`PSRAM_CTRL_ADDR, "CTRL REG", $random & {`PSRAM_CTRL_WIDTH{1'b1}}, Helper::EQUL);
    this.write(`PSRAM_CTRL_ADDR, '1);
    this.wr_rd_check(`PSRAM_CMD_ADDR,  "CMD REG",  $random & {`PSRAM_CMD_WIDTH{1'b1}},  Helper::EQUL);
    this.wr_rd_check(`PSRAM_CCMD_ADDR, "CCMD REG", $random & {`PSRAM_CCMD_WIDTH{1'b1}}, Helper::EQUL);
    this.wr_rd_check(`PSRAM_WAIT_ADDR, "WAIT REG", $random & {`PSRAM_WAIT_WIDTH{1'b1}}, Helper::EQUL);
    this.wr_rd_check(`PSRAM_ADDR_ADDR, "ADDR REG", $random & {`PSRAM_ADDR_WIDTH{1'b1}}, Helper::EQUL);
  end
  // verilog_format: on
endtask

task automatic PSRAMTest::test_cfg_wr_rd();
  bit [31:0] ctrl_val = '0, cmd_val = '0, ccmd_val = '0;
  bit [31:0] wait_val = '0, addr_val = '0, data_val = '0;
  repeat (400 * 3) @(posedge this.apb4.pclk);
  $display("%t === [test psram cfg wr rd] ===", $time);
  // wr cmd
  this.write(`PSRAM_CTRL_ADDR, ctrl_val);
  ctrl_val[1]    = 1'b1;  // cfg mode
  ctrl_val[3:2]  = 2'b00;  // div4
  ctrl_val[11:4] = 8'd6;  // recy 6 cycle
  this.write(`PSRAM_CTRL_ADDR, ctrl_val);
  ccmd_val[7:0] = 8'hC0;
  this.write(`PSRAM_CCMD_ADDR, ccmd_val);
  // wait_val[7:0] = 
  addr_val[7:0] = 8'h04;
  this.write(`PSRAM_ADDR_ADDR, addr_val);
  // data_val[7:0] = 8'b00_1_100_00;
  data_val[7:0] = 8'b010_00_000;
  this.write(`PSRAM_DATA_ADDR, data_val);
  repeat (400 * 2) @(posedge this.apb4.pclk);

  // this.write(`PSRAM_WAIT_ADDR, 32'h0501);
  // this.write(`PSRAM_CFG_ADDR, 32'h40C0);
  // this.write(`PSRAM_CTRL_ADDR, 32'b1000_1_1);  // MA: 8 CFLG: 1 EN: 1
  // this.write(`PSRAM_DATA_ADDR, 8'h0);
  // repeat (400 * 3) @(posedge this.apb4.pclk);
  // this.read(`PSRAM_DATA_ADDR);
  // repeat (400 * 3) @(posedge this.apb4.pclk);
  // // this.write(`psram)
endtask

task automatic PSRAMTest::test_global_reset();
  $display("%t === [test psram global reset] ===", $time);
endtask

task automatic PSRAMTest::test_bus_wr_rd();
  $display("%t === [test psram bus wr rd] ===", $time);
endtask
`endif
