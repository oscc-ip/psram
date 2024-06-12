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
  extern task automatic test_clk_div(input bit [31:0] run_times = 10);
endclass

function PSRAMTest::new(string name, virtual apb4_if.master apb4, virtual psram_if.tb psram);
  super.new("apb4_master", apb4);
  this.name             = name;
  this.apb4             = apb4;
  this.psram            = psram;
endfunction

task automatic PSRAMTest::test_reset_reg();
  super.test_reset_reg();
  // verilog_format: off
  this.rd_check(`PSRAM_CTRL_ADDR, "CTRL REG", 32'b0 & {`PSRAM_CTRL_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`PSRAM_PSCR_ADDR, "PSCR REG", 32'd2 & {`PSRAM_PSCR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  // verilog_format: on
endtask

task automatic PSRAMTest::test_wr_rd_reg(input bit [31:0] run_times = 1000);
  super.test_wr_rd_reg();
  // verilog_format: off
  for (int i = 0; i < run_times; i++) begin
    this.wr_rd_check(`PSRAM_CTRL_ADDR, "CTRL REG", $random & {`PSRAM_CTRL_WIDTH{1'b1}}, Helper::EQUL);
  end
  // verilog_format: on
endtask

task automatic PSRAMTest::test_clk_div(input bit [31:0] run_times = 10);
  $display("=== [test psram clk div] ===");
endtask

`endif