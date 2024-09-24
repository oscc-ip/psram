/*
    Copyright 2020 Efabless Corp.

    Author: Mohamed Shalan (mshalan@efabless.com)

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at:
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// psram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "shift_reg.sv"
`include "psram_define.sv"

// clk_i/psram_sck_o = 4
module psram_core (
    input  logic                         clk_i,
    input  logic                         rst_n_i,
    output logic                         psram_sck_o,
    output logic                         psram_ce_o,
    output logic [                  7:0] psram_io_en_o,
    input  logic [                  7:0] psram_io_in_i,
    output logic [                  7:0] psram_io_out_o,
    output logic                         psram_dqs_en_o,
    input  logic                         psram_dqs_in_i,
    output logic                         psram_dqs_out_o
);


endmodule
