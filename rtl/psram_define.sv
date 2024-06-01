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
 * BITS:   | 31:1 | 0  |
 * FIELDS: | RES  | EN |
 * PERMS:  | NONE | RW |
 * ----------------------------------------------------
 * PSRAM_PSCR:
 * BITS:   | 31:20 | 19:0 |
 * FIELDS: | RES   | PSCR |
 * PERMS:  | NONE  | RW   |
 * -----------------------------------------------------
 * PSRAM_CMD:
 * BITS:   | 31:8 | 7:0 |
 * FIELDS: | RES  | CMD |
 * PERMS:  | NONE | RW  |
 * -----------------------------------------------------
 * PSRAM_ADR:
 * BITS:   | 31:0 |
 * FIELDS: | ADR  |
 * PERMS:  | RW   |
 * -----------------------------------------------------
 * PSRAM_WAIT:
 * BITS:   | 31:8 | 7:0  |
 * FIELDS: | RES  | WAIT |
 * PERMS:  | NONE | RW   |
 * -----------------------------------------------------
 * PSRAM_STAT:
 * BITS:   | 31:1 | 0    |
 * FIELDS: | RES  | OVIF |
 * PERMS:  | NONE | RO   |
 * -----------------------------------------------------
*/

// OPI linear Burst:
// 1. start on even address
// 2. read has no min and max burst length limit
// 3. write has min burst 2B limit
// verilog_format: off
`define PSRAM_CTRL 4'b0000 // BASEADDR + 0x00
`define PSRAM_PSCR 4'b0001 // BASEADDR + 0x04
`define PSRAM_CNT  4'b0010 // BASEADDR + 0x08
`define PSRAM_CMP  4'b0011 // BASEADDR + 0x0C
`define PSRAM_STAT 4'b0100 // BASEADDR + 0x10

`define PSRAM_CTRL_ADDR {26'b0, `PSRAM_CTRL, 2'b00}
`define PSRAM_PSCR_ADDR {26'b0, `PSRAM_PSCR, 2'b00}
`define PSRAM_CNT_ADDR  {26'b0, `PSRAM_CNT , 2'b00}
`define PSRAM_CMP_ADDR  {26'b0, `PSRAM_CMP , 2'b00}
`define PSRAM_STAT_ADDR {26'b0, `PSRAM_STAT, 2'b00}

`define PSRAM_CTRL_WIDTH 8
`define PSRAM_PSCR_WIDTH 20
`define PSRAM_CNT_WIDTH  32
`define PSRAM_CMP_WIDTH  32
`define PSRAM_STAT_WIDTH 1

`define PSRAM_PSCR_MIN_VAL  {{(`PSRAM_PSCR_WIDTH-2){1'b0}}, 2'd2}
// verilog_format: on

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
