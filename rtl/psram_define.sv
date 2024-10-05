// Copyright (c) 2023 Beijing Institute of Open Source Chip
// psram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_PSRAM_DEF_SV
`define INC_PSRAM_DEF_SV

/* register mapping
 * PSRAM_CTRL:
 * BITS:   | 31:16 | 15:14 | 13:12 | 11:4 | 3:2  | 1    | 0  |
 * FIELDS: | RES   | TCHD  | TCSP  | RECY | PSCR | CFLG | EN |
 * PERMS:  | NONE  | RW    | RW    | RW   | RW   | RW   | RW |
 * -----------------------------------------------------------
 * PSRAM_CMD(wr when in config mode):
 * BITS:   | 31:16 | 15:8 | 7:0  |
 * FIELDS: | RES   | RCMD | WCMD |
 * PERMS:  | NONE  | RW   | RW   |
 * -----------------------------------------------------------
 * PSRAM_CCMD(wr when in config mode):
 * BITS:   | 31:8 | 7:0  |
 * FIELDS: | RES  | CCMD |
 * PERMS:  | NONE | RW   |
 * -----------------------------------------------------------
 * PSRAM_WAIT(wr when in config mode):
 * BITS:   | 31:16 | 15:8 | 7:0 |
 * FIELDS: | RES   | RLC  | WLC |
 * PERMS:  | NONE  | RW   | RW  |
 * -----------------------------------------------------------
 * PSRAM_ADDR(wr when in config mode):
 * BITS:   | 31:0 |
 * FIELDS: | ADDR |
 * PERMS:  | RW   |
 * -----------------------------------------------------------
 * PSRAM_DATA(wr when in config mode):
 * BITS:   | 31:8 | 7:0  |
 * FIELDS: | RES  | DATA |
 * PERMS:  | NONE | RW   |
 * -----------------------------------------------------
 * PSRAM_STAT:
 * BITS:   | 31:3 | 2    | 1:0 |
 * FIELDS: | RES  | DONE | CRM |
 * PERMS:  | NONE | RO   | RO  |
 * -----------------------------------------------------
*/

// OPI linear Burst:
// 1. start on even address
// 2. read has no min and max burst length limit
// 3. write has min burst 2B limit
// verilog_format: off
`define PSRAM_CTRL 4'b0000 // BASEADDR + 0x00
`define PSRAM_CMD  4'b0001 // BASEADDR + 0x04
`define PSRAM_CCMD 4'b0010 // BASEADDR + 0x08
`define PSRAM_WAIT 4'b0011 // BASEADDR + 0x0C
`define PSRAM_ADDR 4'b0100 // BASEADDR + 0x10
`define PSRAM_DATA 4'b0101 // BASEADDR + 0x14
`define PSRAM_STAT 4'b0110 // BASEADDR + 0x18


`define PSRAM_CTRL_ADDR {26'b0, `PSRAM_CTRL, 2'b00}
`define PSRAM_CMD_ADDR  {26'b0, `PSRAM_CMD , 2'b00}
`define PSRAM_CCMD_ADDR {26'b0, `PSRAM_CCMD, 2'b00}
`define PSRAM_WAIT_ADDR {26'b0, `PSRAM_WAIT, 2'b00}
`define PSRAM_ADDR_ADDR {26'b0, `PSRAM_ADDR, 2'b00}
`define PSRAM_DATA_ADDR {26'b0, `PSRAM_DATA, 2'b00}
`define PSRAM_STAT_ADDR {26'b0, `PSRAM_STAT, 2'b00}


`define PSRAM_CTRL_WIDTH 16
`define PSRAM_CMD_WIDTH  16
`define PSRAM_CCMD_WIDTH 8
`define PSRAM_WAIT_WIDTH 16
`define PSRAM_ADDR_WIDTH 32
`define PSRAM_DATA_WIDTH 8
`define PSRAM_STAT_WIDTH 3
// verilog_format: on

`define PSRAM_PSCR_DIV4  2'b00
`define PSRAM_PSCR_DIV8  2'b01
`define PSRAM_PSCR_DIV16 2'b10
`define PSRAM_PSCR_DIV32 2'b11

`define PSRAM_MODE_SPI  2'b00
`define PSRAM_MODE_QSPI 2'b01
`define PSRAM_MODE_QPI  2'b10
`define PSRAM_MODE_OPI  2'b11


`define PSRAM_FSM_IDLE   4'b0000
`define PSRAM_FSM_TCSP   4'b0001
`define PSRAM_FSM_INST   4'b0010
`define PSRAM_FSM_ADDR   4'b0011
`define PSRAM_FSM_LATN   4'b0100
`define PSRAM_FSM_WDATA  4'b0101
`define PSRAM_FSM_RDATA  4'b0110
`define PSRAM_FSM_TCHD   4'b0111
`define PSRAM_FSM_RECY   4'b1000


interface psram_if ();
  logic       psram_sck_o;
  logic       psram_ce_o;
  logic [7:0] psram_io_en_o;
  logic [7:0] psram_io_in_i;
  logic [7:0] psram_io_out_o;
  logic       psram_dqs_en_o;
  logic       psram_dqs_in_i;
  logic       psram_dqs_out_o;
  logic       irq_o;

  modport dut(
      output psram_sck_o,
      output psram_ce_o,
      output psram_io_en_o,
      input  psram_io_in_i,
      output psram_io_out_o,
      output psram_dqs_en_o,
      input  psram_dqs_in_i,
      output psram_dqs_out_o,
      output irq_o
  );

  // verilog_format: off
  modport tb(
      input  psram_sck_o,
      input  psram_ce_o,
      input  psram_io_en_o,
      output psram_io_in_i,
      input  psram_io_out_o,
      input  psram_dqs_en_o,
      output psram_dqs_in_i,
      input  psram_dqs_out_o,
      input  irq_o
  );
  // verilog_format: on
endinterface
`endif
