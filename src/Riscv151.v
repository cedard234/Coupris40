`include "const.vh"

module Riscv151(
    input clk,
    input reset,

    // Memory system ports
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    input [31:0] dcache_dout,
    input [31:0] icache_dout,
    input stall,
    output [31:0] csr

);

  // From left to right on the pipeline plot, the modules are:

  // Stage 0, before PC and IMEM
  wire PCSel;
  wire [`CPU_DATA_BITS-1: 0] s0_pc_add_4;
  wire [`CPU_DATA_BITS-1: 0] s0_pc_alu;
  wire [`CPU_DATA_BITS-1: 0] s0_pc_next;

  s0_PC_MUX s0_pc_mux(
    .s0_pc_add_4(s0_pc_add_4),
    .s0_pc_alu(s0_pc_alu),
    .s0_pc_next(s0_pc_next),
    .PCSel(PCSel)
  );

  s0_PC s0_pc(
    .clk(clk),
    .reset(reset),
    .s0_pc_next(s0_pc_next),
    .s0_pc_alu(s0_pc_alu),
    .s0_pc_add_4(s0_pc_add_4),
    .s0_pc(s0_pc)
  );

  assign icache_addr = s0_pc_next;

  s0_PC_ADD s0_pc_add(
    .s0_pc(s0_pc),
    .s0_pc_add_4(s0_pc_add_4)
  );

  // Stage 0, after PC and IMEM
  wire [`CPU_INST_BITS-1: 0] s0_inst;
  assign s0_inst = icache_dout;

  // Two stage 2 signals are defined here, because they are used in stage 0
  wire [4:0] AddrD;
  wire RegWEn;
  wire [`CPU_DATA_BITS-1: 0] s2_DataD;

  // two stage 1 signals are defined here as the output
  wire [`CPU_DATA_BITS-1: 0] s1_dataA;
  wire [`CPU_DATA_BITS-1: 0] s1_dataB;

  s0_REG s0_reg(
    .clk(clk),
    .reset(reset),
    .RegWEn(RegWEn),
    .s0_AddrA(s0_inst[19:15]),
    .s0_AddrB(s0_inst[24:20]),
    .s2_AddrD(AddrD),
    .s2_DataD(s2_DataD),
    .s1_DataA(s1_dataA),
    .s1_DataB(s1_dataB)
  );

  wire [6:0] ImmSel;
  wire [`CPU_DATA_BITS-1: 0] s0_imm;

  s0_IMM_GEN s0_imm_gen(
    .ImmSel(ImmSel),
    .s0_inst(s0_inst),
    .s0_imm(s0_imm)
  );

  // Stage 0 ends, stage 1 begins. Insert registers here.
  reg [`CPU_DATA_BITS-1: 0] s1_imm;
  reg [`CPU_DATA_BITS-1: 0] s1_pc;

  always@(posedge clk) begin
    if (reset) begin
      s1_imm <= 0;
      s1_pc <= 0;
    end
    else begin
      s1_imm <= s0_imm;
      s1_pc <= s0_pc;
    end
  end

  // Stage 1 begins
  wire BrUn, BrEq, BrLT;

  s1_BRANCH_COMP s1_branch_comp(
    .s1_dataA(s1_dataA),
    .s1_dataB(s1_dataB),
    .BrUn(BrUn),
    .BrEq(BrEq),
    .BrLT(BrLT)
  );

  wire [`CPU_DATA_BITS-1: 0] s1_alu_in1;
  wire [`CPU_DATA_BITS-1: 0] s1_alu_in2;
  wire ASel, BSel;

  s1_dataA_MUX s1_dataA_mux(
    .s1_pc(s1_pc),
    .s1_dataA(s1_dataA),
    .ASel(ASel)
    .s1_ALU_in1(s1_ALU_in1)
  );

  s1_dataB_MUX s1_dataB_mux(
    .s1_imm(s1_imm),
    .s1_dataB(s1_dataB),
    .BSel(BSel),
    .s1_ALU_in2(s1_ALU_in2)
  );

  wire [3:0] ALUSel;
  wire [`CPU_DATA_BITS-1: 0] s1_alu;

  ALU s1_alu(
    .A(s1_alu_in1),
    .B(s1_alu_in2),
    .ALUop(ALUSel),
    .Out(s1_alu)
  );

  assign dcache_addr = s1_alu;
  assign dcache_din = s1_dataB;

  // Stage 1 ends, stage 2 begins. Insert registers here.
  reg [`CPU_DATA_BITS-1: 0] s2_alu;
  reg [`CPU_INST_BITS-1: 0] s2_pc;

  always@(posedge clk) begin
    if (reset) begin
      s2_alu <= 0;
      s2_pc <= 0;
    end
    else begin
      s2_alu <= s1_alu;
      s2_pc <= s1_pc;
    end
  end

  // Stage 2 begins
  wire MemRW; //TODO: how does MemRW related to the dcache_we?
  wire WBSel;
  wire [`CPU_DATA_BITS-1: 0] s2_wb;

  // s2_DataD was already well defined as:
  //  wire [`CPU_DATA_BITS-1: 0] s2_DataD;
  s2_WB_MUX s2_wb_mux(
    .s2_pc(s2_pc),
    .s2_ALU(s2_alu),
    .s2_dataB(dcache_dout),
    .WBSel(WBSel),
    .s2_wb(s2_DataD)
  );

  // Finally, the control logic
  control control(
    .clk(clk),
    .reset(reset),
    .s0_inst(s0_inst),
    .BrEq(BrEq),
    .BrLT(BrLT),
    .PCSel(PCSel),
    .ImmSel(ImmSel),
    .RegWEN(RegWEn),
    .AddrD(AddrD),
    .ASel(ASel),
    .BSel(BSel),
    .ALUSel(ALUSel),
    .MemRW(MemRW),
    .WBSel(WBSel)
  );

endmodule
