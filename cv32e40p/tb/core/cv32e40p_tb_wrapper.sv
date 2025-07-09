// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Wrapper for a CV32E40P testbench, containing CV32E40P, Memory and stdout peripheral
// Contributor: Robert Balas <balasr@student.ethz.ch>
// Module renamed from riscv_wrapper to cv32e40p_tb_wrapper because (1) the
// name of the core changed, and (2) the design has a cv32e40p_wrapper module.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-0.51

module cv32e40p_tb_wrapper
    #(parameter // Parameters used by TB
                INSTR_RDATA_WIDTH = 32,
                RAM_ADDR_WIDTH    = 20,
                BOOT_ADDR         = 'h80,
                DM_HALTADDRESS    = 32'h1A11_0800,
                HART_ID           = 32'h0000_0000,
                // Parameters used by DUT
                COREV_PULP        = 0,
                COREV_CLUSTER     = 0,
                FPU               = 0,
                ZFINX             = 0,
                NUM_MHPMCOUNTERS  = 1
    )
    (input logic         clk_i,
     input logic         rst_ni,

     input logic         fetch_enable_i,
     output logic        tests_passed_o,
     output logic        tests_failed_o,
     output logic [31:0] exit_value_o,
     output logic        exit_valid_o);

    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [31:0]                  instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    // signals to debug unit
    logic                         debug_req;

    // irq signals (not used)
    logic [0:31]                  irq;
    logic [0:4]                   irq_id_in;
    logic                         irq_ack;
    logic [0:4]                   irq_id_out;
    logic                         irq_sec;


    // interrupts (only timer for now)
    assign irq_sec     = '0;

//    // core log reports parameter usage and illegal instructions to the logfile
//    // MIKET: commenting out as the cv32e40p RTL wrapper does this as well.
//    cv32e40p_core_log
//     #(
//          .COREV_PULP            ( COREV_PULP            ),
//          .COREV_CLUSTER         ( COREV_CLUSTER         ),
//          .FPU                   ( FPU                   ),
//          .ZFINX                 ( ZFINX                 ),
//          .NUM_MHPMCOUNTERS      ( NUM_MHPMCOUNTERS      ))
//    core_log_i(
//          .clk_i              ( cv32e40p_core_i.id_stage_i.clk              ),
//          .is_decoding_i      ( cv32e40p_core_i.id_stage_i.is_decoding_o    ),
//          .illegal_insn_dec_i ( cv32e40p_core_i.id_stage_i.illegal_insn_dec ),
//          .hart_id_i          ( cv32e40p_core_i.hart_id_i                   ),
//          .pc_id_i            ( cv32e40p_core_i.pc_id                       )
//      );

    
    parameter APU_NARGS_CPU = 3;
    parameter APU_WOP_CPU = 6;
    parameter APU_NDSFLAGS_CPU = 15;
    parameter APU_NUSFLAGS_CPU = 5;
    // Core to FPU
    logic                              apu_busy;
    logic                              apu_req;
    logic [   APU_NARGS_CPU-1:0][31:0] apu_operands;
    logic [     APU_WOP_CPU-1:0]       apu_op;
    logic [APU_NDSFLAGS_CPU-1:0]       apu_flags;

    // FPU to Core
    logic                              apu_gnt;
    logic                              apu_rvalid;
    logic [                31:0]       apu_rdata;
    logic [APU_NUSFLAGS_CPU-1:0]       apu_rflags;

    // instantiate the core
    cv32e40p_core #(
                 .COREV_PULP       (COREV_PULP),
                 .COREV_CLUSTER    (COREV_CLUSTER),
                 .FPU              (FPU),
                 .ZFINX            (ZFINX),
                 .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS)
                )
    cv32e40p_core_i
        (
         .clk_i                  ( clk_i                 ),
         .rst_ni                 ( rst_ni                ),

         .pulp_clock_en_i        ( '1                    ),
         .scan_cg_en_i           ( '0                    ),

         .boot_addr_i            ( BOOT_ADDR             ),
         .dm_halt_addr_i         ( DM_HALTADDRESS        ),
         .hart_id_i              ( HART_ID               ),

         .instr_req_o            ( instr_req             ),
         .instr_gnt_i            ( instr_gnt             ),
         .instr_rvalid_i         ( instr_rvalid          ),
         .instr_addr_o           ( instr_addr            ),
         .instr_rdata_i          ( instr_rdata           ),

         .data_req_o             ( data_req              ),
         .data_gnt_i             ( data_gnt              ),
         .data_rvalid_i          ( data_rvalid           ),
         .data_we_o              ( data_we               ),
         .data_be_o              ( data_be               ),
         .data_addr_o            ( data_addr             ),
         .data_wdata_o           ( data_wdata            ),
         .data_rdata_i           ( data_rdata            ),

         .apu_busy_o             ( apu_busy              ),
         .apu_req_o              ( apu_req               ),
         .apu_gnt_i              ( apu_gnt               ),
         .apu_operands_o         ( apu_operands          ),
         .apu_op_o               ( apu_op                ),
         .apu_flags_o            ( apu_flags             ),
         .apu_rvalid_i           ( apu_rvalid            ),
         .apu_result_i           ( apu_rdata             ),
         .apu_flags_i            ( apu_rflags            ), // APU_NUSFLAGS_CPU

         // Interrupts verified in UVM environment
         .irq_i                  ( {32{1'b0}}            ),
         .irq_ack_o              ( irq_ack               ),
         .irq_id_o               ( irq_id_out            ),

         .debug_req_i            ( debug_req             ),

         .fetch_enable_i         ( fetch_enable_i        ),
         .core_sleep_o           ( core_sleep_o          )
       );
       
      generate
        if (FPU) begin : fpu_gen
          
          assign apu_clk_en = apu_req | apu_busy;

          // FPU clock gate
          cv32e40p_clock_gate core_clock_gate_i (
              .clk_i       (clk_i),
              .en_i        (apu_clk_en),
              .scan_cg_en_i(scan_cg_en_i),
              .clk_o       (apu_clk)
          );

          // Instantiate the FPU wrapper
          cv32e40p_fp_wrapper #(
              .FPU_ADDMUL_LAT(0),
              .FPU_OTHERS_LAT(0)
          ) fp_wrapper_i (
              .clk_i         (apu_clk),
              .rst_ni        (rst_ni),
              .apu_req_i     (apu_req),
              .apu_gnt_o     (apu_gnt),
              .apu_operands_i(apu_operands),
              .apu_op_i      (apu_op),
              .apu_flags_i   (apu_flags),
              .apu_rvalid_o  (apu_rvalid),
              .apu_rdata_o   (apu_rdata),
              .apu_rflags_o  (apu_rflags)
          );
        end else begin : no_fpu_gen
          // Drive FPU output signals to 0
          assign apu_gnt    = '0;
          assign apu_rvalid = '0;
          assign apu_rdata  = '0;
          assign apu_rflags = '0;
        end
      endgenerate

    // this handles read to RAM and memory mapped pseudo peripherals
    mm_ram
        #(.RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH))
    ram_i
        (.clk_i          ( clk_i                                     ),
         .rst_ni         ( rst_ni                                    ),
         .dm_halt_addr_i ( DM_HALTADDRESS                            ),

         .instr_req_i    ( instr_req                                 ),
         .instr_addr_i   ( { {10{1'b0}},
                             instr_addr[RAM_ADDR_WIDTH-1:0]
                           }                                         ),
         .instr_rdata_o  ( instr_rdata                               ),
         .instr_rvalid_o ( instr_rvalid                              ),
         .instr_gnt_o    ( instr_gnt                                 ),

         .data_req_i     ( data_req                                  ),
         .data_addr_i    ( data_addr                                 ),
         .data_we_i      ( data_we                                   ),
         .data_be_i      ( data_be                                   ),
         .data_wdata_i   ( data_wdata                                ),
         .data_rdata_o   ( data_rdata                                ),
         .data_rvalid_o  ( data_rvalid                               ),
         .data_gnt_o     ( data_gnt                                  ),

         .irq_id_i       ( irq_id_out                                ),
         .irq_ack_i      ( irq_ack                                   ),
         .irq_o          ( irq                                       ),

         .debug_req_o    ( debug_req                                 ),

         .pc_core_id_i   ( cv32e40p_core_i.pc_id                     ),

         .tests_passed_o ( tests_passed_o                            ),
         .tests_failed_o ( tests_failed_o                            ),
         .exit_valid_o   ( exit_valid_o                              ),
         .exit_value_o   ( exit_value_o                              ));

endmodule // cv32e40p_tb_wrapper
