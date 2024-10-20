// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// common is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "setting.sv"
`include "register.sv"
`include "edge_det.sv"
`include "axi4_define.sv"
`include "axi4_addr_gen.sv"

// each usr block capacity is 4KB
module psram_axi4_slv_fsm #(
    parameter int USR_ADDR_SIZE  = 64 * 1024 * 1024,
    parameter int USR_ADDR_WIDTH = $clog2(USR_ADDR_SIZE)  // NOTE: dont modify!
) (
    input  logic                                      aclk,
    input  logic                                      aresetn,
    input  logic [                `AXI4_ID_WIDTH-1:0] awid,
    input  logic [              `AXI4_ADDR_WIDTH-1:0] awaddr,
    input  logic [                               7:0] awlen,
    input  logic [                               2:0] awsize,
    input  logic [                               1:0] awburst,
    input  logic                                      awlock,
    input  logic [                               3:0] awcache,
    input  logic [                               2:0] awprot,
    input  logic [                               3:0] awqos,
    input  logic [                               3:0] awregion,
    input  logic [              `AXI4_USER_WIDTH-1:0] awuser,
    input  logic                                      awvalid,
    output logic                                      awready,
    input  logic [              `AXI4_DATA_WIDTH-1:0] wdata,
    input  logic [            `AXI4_DATA_WIDTH/8-1:0] wstrb,
    input  logic                                      wlast,
    input  logic [              `AXI4_USER_WIDTH-1:0] wuser,
    input  logic                                      wvalid,
    output logic                                      wready,
    output logic [                `AXI4_ID_WIDTH-1:0] bid,
    output logic [                               1:0] bresp,
    output logic [              `AXI4_USER_WIDTH-1:0] buser,
    output logic                                      bvalid,
    input  logic                                      bready,
    input  logic [                `AXI4_ID_WIDTH-1:0] arid,
    input  logic [              `AXI4_ADDR_WIDTH-1:0] araddr,
    input  logic [                               7:0] arlen,
    input  logic [                               2:0] arsize,
    input  logic [                               1:0] arburst,
    input  logic                                      arlock,
    input  logic [                               3:0] arcache,
    input  logic [                               2:0] arprot,
    input  logic [                               3:0] arqos,
    input  logic [                               3:0] arregion,
    input  logic [              `AXI4_USER_WIDTH-1:0] aruser,
    input  logic                                      arvalid,
    output logic                                      arready,
    output logic [                `AXI4_ID_WIDTH-1:0] rid,
    output logic [              `AXI4_DATA_WIDTH-1:0] rdata,
    output logic [                               1:0] rresp,
    output logic                                      rlast,
    output logic [              `AXI4_USER_WIDTH-1:0] ruser,
    output logic                                      rvalid,
    input  logic                                      rready,
    // user interface
    output logic                                      usr_xfer_start_o,
    output logic                                      usr_wen_o,
    output logic [                               7:0] usr_wlen_o,
    output logic [USR_ADDR_WIDTH-`AXI4_DATA_BLOG-1:0] usr_addr_o,
    output logic [             `AXI4_WSTRB_WIDTH-1:0] usr_bm_o,
    output logic [              `AXI4_DATA_WIDTH-1:0] usr_dat_o,
    input  logic [              `AXI4_DATA_WIDTH-1:0] usr_dat_i,
    input  logic                                      usr_wready_i,
    input  logic                                      usr_rvalid_i
);

  // AXI has the following rules governing the use of bursts:
  // - a burst must not cross a 4KB address boundary
  typedef enum logic [1:0] {
    FIXED = 2'b00,
    INCR  = 2'b01,
    WRAP  = 2'b10
  } axi4_burst_t;

  typedef struct packed {
    logic [`AXI4_ID_WIDTH-1:0]   id;
    logic [`AXI4_ADDR_WIDTH-1:0] addr;
    logic [7:0]                  len;
    logic [2:0]                  size;
    axi4_burst_t                 burst;
  } axi4_req_t;

  typedef enum logic [2:0] {
    IDLE,
    READ,
    WRITE,
    SEND_B,
    WAIT_WVALID
  } axi4_fsm_t;

  axi4_req_t s_axi_req_d, s_axi_req_q;
  axi4_fsm_t s_state_d, s_state_q;
  logic [8:0] s_trans_cnt_d, s_trans_cnt_q;
  logic [    `AXI4_ADDR_WIDTH-1:0] s_xfer_nxt_addr;
  logic [`AXI4_ADDR_OFT_WIDTH-1:0] s_oft_addr;
  logic [USR_ADDR_WIDTH-`AXI4_DATA_BLOG-1:0] s_usr_addr_d, s_usr_addr_q;
  logic [`AXI4_WSTRB_WIDTH-1:0] s_usr_bm_d, s_usr_bm_q;
  logic [`AXI4_DATA_WIDTH-1:0] s_usr_wr_dat_d, s_usr_wr_dat_q;
  logic s_xfer_start_flag, s_xfer_start_trg;
  logic s_rvalid_d, s_rvalid_q;

  assign wready          = usr_wready_i;
  assign rvalid          = s_rvalid_q;
  // reg
  assign usr_addr_o      = s_usr_addr_q;
  assign usr_bm_o        = s_usr_bm_q;
  assign usr_dat_o       = s_usr_wr_dat_q;

  assign s_xfer_nxt_addr = {s_axi_req_q.addr[`AXI4_ADDR_WIDTH-1:`AXI4_ADDR_OFT_WIDTH], s_oft_addr};
  axi4_addr_gen u_axi4_addr_gen (
      .alen_i  (s_axi_req_q.len),
      .asize_i (s_axi_req_q.size),
      .aburst_i(s_axi_req_q.burst),
      .addr_i  (s_axi_req_q.addr[`AXI4_ADDR_OFT_WIDTH-1:0]),
      .addr_o  (s_oft_addr)
  );

  always_comb begin
    // reg
    s_state_d        = s_state_q;
    s_axi_req_d      = s_axi_req_q;
    s_axi_req_d.addr = s_axi_req_q.addr;
    s_trans_cnt_d    = s_trans_cnt_q;
    s_usr_addr_d     = s_usr_addr_q;
    s_usr_bm_d       = s_usr_bm_q;
    s_usr_wr_dat_d   = s_usr_wr_dat_q;
    // port
    // usr_xfer_start_o = '0;
    usr_wen_o        = '0;
    usr_wlen_o       = '0;
    // const
    arready          = '0;
    rdata            = usr_dat_i;
    rresp            = '0;
    rlast            = '0;
    rid              = s_axi_req_q.id;
    ruser            = '0;
    awready          = '0;
    bvalid           = '0;
    bresp            = '0;
    bid              = s_axi_req_q.id;
    buser            = '0;

    case (s_state_q)
      IDLE: begin
        if (arvalid) begin
          arready       = 1'b1;
          s_axi_req_d   = {arid, araddr, arlen, arsize, arburst};
          s_usr_addr_d  = araddr[USR_ADDR_WIDTH-1:`AXI4_DATA_BLOG];
          s_trans_cnt_d = 1;
          s_state_d     = READ;

        end else if (awvalid) begin
          awready      = 1'b1;
          s_axi_req_d  = {awid, awaddr, awlen, awsize, awburst};
          s_usr_addr_d = awaddr[USR_ADDR_WIDTH-1:`AXI4_DATA_BLOG];

          if (wvalid) begin
            usr_wlen_o     = awlen;
            usr_wen_o      = 1'b1;
            s_usr_bm_d     = wstrb;
            s_usr_wr_dat_d = wdata;
          end
          if (wvalid && wready) begin
            s_state_d = wlast ? SEND_B : WRITE;
          end else s_state_d = WRITE;
        end
      end

      READ: begin
        rid   = s_axi_req_q.id;
        rlast = s_trans_cnt_q == s_axi_req_q.len + 1;
        if (rvalid && rready) begin
          s_axi_req_d.addr = s_xfer_nxt_addr;
          case (s_axi_req_q.burst)
            FIXED, INCR: s_usr_addr_d = s_xfer_nxt_addr[USR_ADDR_WIDTH-1:`AXI4_DATA_BLOG];
            default:     s_usr_addr_d = '0;
          endcase
          if (rlast) s_state_d = IDLE;
          s_trans_cnt_d = s_trans_cnt_q + 1;
        end
      end

      WRITE: begin
        if (wvalid) begin
          usr_wlen_o     = s_axi_req_q.len;
          usr_wen_o      = 1'b1;
          s_usr_bm_d     = wstrb;
          s_usr_wr_dat_d = wdata;

          if (wready) begin
            s_axi_req_d.addr = s_xfer_nxt_addr;
            case (s_axi_req_q.burst)
              FIXED, INCR: s_usr_addr_d = s_xfer_nxt_addr[USR_ADDR_WIDTH-1:`AXI4_DATA_BLOG];
              default:     s_usr_addr_d = '0;
            endcase
            if (wlast) s_state_d = SEND_B;
          end
        end
      end
      SEND_B: begin
        bid    = s_axi_req_q.id;
        bvalid = 1'b1;
        if (bready && bvalid) s_state_d = IDLE;
      end
    endcase
  end

  dffr #(9) u_cnt_dffr (
      aclk,
      aresetn,
      s_trans_cnt_d,
      s_trans_cnt_q
  );

  always_ff @(posedge aclk, negedge aresetn) begin
    if (~aresetn) begin
      s_state_q   <= #`REGISTER_DELAY IDLE;
      s_axi_req_q <= #`REGISTER_DELAY '0;
    end else begin
      s_state_q   <= #`REGISTER_DELAY s_state_d;
      s_axi_req_q <= #`REGISTER_DELAY s_axi_req_d;
    end
  end

  dffr #(USR_ADDR_WIDTH - `AXI4_DATA_BLOG) u_usr_addr_dffr (
      aclk,
      aresetn,
      s_usr_addr_d,
      s_usr_addr_q
  );

  dffr #(`AXI4_WSTRB_WIDTH) u_usr_bm_dffr (
      aclk,
      aresetn,
      s_usr_bm_d,
      s_usr_bm_q
  );

  dffr #(`AXI4_DATA_WIDTH) u_usr_wr_dat_dffr (
      aclk,
      aresetn,
      s_usr_wr_dat_d,
      s_usr_wr_dat_q
  );


  always_comb begin
    if (s_state_q == READ) begin
      s_rvalid_d = s_rvalid_q;
      if (~s_rvalid_q && usr_rvalid_i) s_rvalid_d = 1'b1;
      else if (s_rvalid_q && rready) s_rvalid_d = 1'b0;
    end else s_rvalid_d = 1'b0;
  end
  dffr #(1) u_rvalid_dffr (
      aclk,
      aresetn,
      s_rvalid_d,
      s_rvalid_q
  );

  // delay one cycle
  assign s_xfer_start_flag = (s_state_q == IDLE && awvalid && wvalid) ||
                             (s_state_q == WRITE && wvalid) || (s_state_q == READ) ||
                             (s_state_q == READ && rready);
  edge_det_re #(
      .STAGE     (1),
      .DATA_WIDTH(1)
  ) u_usr_xfer_start_edge_det_re (
      .clk_i  (aclk),
      .rst_n_i(aresetn),
      .dat_i  (s_xfer_start_flag),
      .re_o   (s_xfer_start_trg)
  );

  assign usr_xfer_start_o = s_xfer_start_trg || (s_state_q == WRITE && wvalid && ~wlast) ||
                            (s_state_q == READ && rready && ~rlast);
endmodule
