// Copyright (c) 2023 Beijing Institute of Open Source Chip
// psram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.sv"
`include "axi4_if.sv"
`include "gpio_pad.sv"
`include "psram_define.sv"

module axi4_psram_tb ();
  localparam real CLK_PEROID = 1.25;
  logic rst_n_i, clk_i;

  wire s_psram_sck_pad, s_psram_ce_pad, s_psram_dqs_pad, s_psram_dummy_dqs_pad;
  wire [7:0] s_psram_dummy_io_pad, s_psram_io_pad;

  initial begin
    clk_i = 1'b0;
    forever begin
      #(CLK_PEROID / 2) clk_i <= ~clk_i;
    end
  end

  task sim_reset(int delay);
    rst_n_i = 1'b0;
    repeat (delay) @(posedge clk_i);
    #1 rst_n_i = 1'b1;
  endtask

  initial begin
    sim_reset(40);
  end

  apb4_if u_apb4_if (
      clk_i,
      rst_n_i
  );

  axi4_if u_axi4_if (
      clk_i,
      rst_n_i
  );

  psram_if u_psram_if ();


  tri_pd_pad_h u_psram_sck_pad(.i_i(u_psram_if.psram_sck_o),     .oen_i(1'b1),                      .ren_i(),  .c_o(),                          .pad_io(s_psram_sck_pad));
  tri_pd_pad_h u_psram_ce_pad (.i_i(u_psram_if.psram_ce_o),      .oen_i(1'b1),                      .ren_i(),  .c_o(),                          .pad_io(s_psram_ce_pad));
  tri_pd_pad_h u_psram_dqs_pad(.i_i(u_psram_if.psram_dqs_out_o), .oen_i(u_psram_if.psram_dqs_en_o), .ren_i (), .c_o(u_psram_if.psram_dqs_in_i), .pad_io(s_psram_dqs_pad));

  for (genvar i = 0; i < 8; i++) begin : PSRAM_TB_PAD_BLOCK
    tri_pd_pad_h u_psram_io_pad (
        .i_i   (u_psram_if.psram_io_out_o[i]),
        .oen_i (u_psram_if.psram_io_en_o[i]),
        .ren_i (),
        .c_o   (u_psram_if.psram_io_in_i[i]),
        .pad_io(s_psram_io_pad[i])
    );
  end

  test_top u_test_top (
      .apb4 (u_apb4_if.master),
      .psram(u_psram_if.tb)
  );
  axi4_psram u_axi4_psram (
      .apb4 (u_apb4_if.slave),
      .axi4 (u_axi4_if.slave),
      .psram(u_psram_if.dut)
  );

  // NOTE: inst the verilog model here and this model is privated due to the NDA
  psram_model u_psram_model (
      .xCLK  (s_psram_sck_pad),
      .xCEn  (s_psram_ce_pad),
      .xDQSDM({s_psram_dummy_dqs_pad, s_psram_dqs_pad}),
      .xDQ   ({s_psram_dummy_io_pad, s_psram_io_pad})
  );
endmodule
