// Module: control
// Desc:   The module to control the datapath, including signals from PCSel all the way to WBSel. This module should include the 3 stage delay of the instructions for decoding purposes as well.
// Inputs: s0_inst: the instruction from the first stage
//         BrEq: the signal to determine if the branch is equal
//         BrLT: the signal to determine if the branch is less than
// Outputs: PCSel: the signal to select the next PC
//          ImmSel: the signal to select the immediate value, or just the OPCODE
//          RegWEN: the signal to determine if the register file should be written to
//          AddrD: the address to write to in the register file
//          ASel: the signal to select between the PC and dataA from the register file
//          BSel: the signal to select between dataB from the register file and the immediate value
//          ALUSel: the signal to select the ALU's operation
//          MemRW: the signal to select between a read or write to memory
//          WBSel: the signal to select from pc, ALU or memory for the writeback
//

`include "const.vh"
`include "Opcode.vh"
`include "ALUop.vh"

module control(
    input clk,
    input reset,
    input [`CPU_INST_BITS-1: 0] s0_inst,
    input BrEq,
    input BrLT,
    output reg PCSel,
    output reg ImmSel,
    output reg RegWEN,
    output reg [4: 0] AddrD,
    output reg ASel,
    output reg BSel,
    output reg [3: 0] ALUSel,
    output reg MemRW,
    output reg WBSel
);

    reg [`CPU_INST_BITS-1: 0] s0s1_inst, s1s2_inst;

    // The instruction needs to be pipelined:
    always@(posedge clk) begin
        if (reset) begin
            s0s1_inst <= 0;
            s1s2_inst <= 0;
        end
        else begin
            s0s1_inst <= s0_inst;
            s1s2_inst <= s0s1_inst;
        end
    end

    always@(*) begin
        // From left to right on the pipeline plot, the signals are:
        // PCSel
        // PC is NOT PC+4 if and only if the instruction is a JAL, JALR or a BRANCH.
        // If the instruction is a branch, it depends on the branch condition.
        if (s0s1_inst[6:0] == `OPC_JAL ||
            s0s1_inst[6:0] == `OPC_JALR) begin
            PCSel = 1'b1;
        end
        else if (s0s1_inst[6:0] == `OPC_BRANCH) begin
            case(s0s1_inst[14:12])
                `FNC_BEQ: PCSel = BrEq; // Equal: A=B.
                `FNC_BNE: PCSel = ~BrEq; // Not equal: A!=B.
                `FNC_BLT: PCSel = BrLT; // Less than: A<B.
                `FNC_BGE: PCSel = ~BrLT; // Greater than or equal: A>=B, or A!<B.
                `FNC_BLTU: PCSel = BrLT; // Less than unsigned: A<B.
                `FNC_BGEU: PCSel = ~BrLT; // Greater than or equal unsigned: A>=B, or A!<B.
                default: PCSel = 1'b0;
            endcase
        end
        else begin
            PCSel = 1'b0;
        end

        // ImmSel
        // ImmSel is just the opcode.
        ImmSel = s0inst[6:0];

        // RegWEN
        // RegWEN is 1 if and only if the instruction is a: Rtype, Itype, JAL, JALR, or Utype.
        if (s0s1_inst[6:0] == `OPC_ARI_RTYPE ||
            s0s1_inst[6:0] == `OPC_ARI_ITYPE ||
            s0s1_inst[6:0] == `OPC_JAL ||
            s0s1_inst[6:0] == `OPC_JALR ||
            s0s1_inst[6:0] == `OPC_LUI ||
            s0s1_inst[6:0] == `OPC_AUIPC) begin
            RegWEN = 1'b1;
        end
        else begin
            RegWEN = 1'b0;
        end

        // AddrD
        // AddrD is given to the register file only after the instruction has reached the writeback stage.
        AddrD = s1s2_inst[11:7];

        // ASel
        // ASel is 1 if and only if the instruction is a: Branch, JAL or JALR.
        if (s0s1_inst[6:0] == `OPC_BRANCH ||
            s0s1_inst[6:0] == `OPC_JAL ||
            s0s1_inst[6:0] == `OPC_JALR) begin
            ASel = 1'b1;
        end
        else begin
            ASel = 1'b0;
        end

        // BSel
        // BSel is 1 if and only if the instruction is a: Itype, Stype, Branch, JAL, JALR, LUI or AUIPC.
        if (s0s1_inst[6:0] == `OPC_ARI_ITYPE ||
            s0s1_inst[6:0] == `OPC_STORE ||
            s0s1_inst[6:0] == `OPC_BRANCH ||
            s0s1_inst[6:0] == `OPC_JAL ||
            s0s1_inst[6:0] == `OPC_JALR ||
            s0s1_inst[6:0] == `OPC_LUI ||
            s0s1_inst[6:0] == `OPC_AUIPC) begin
            BSel = 1'b1;
        end
        else begin
            BSel = 1'b0;
        end

        // BrUn
        // BrUn is 1 if and only if the instruction is a: BLTU or BGEU.
        if (s0s1_inst[6:0] == `OPC_BRANCH) begin
            case(s0s1_inst[14:12])
                `FNC_BLTU: BrUn = 1'b1;
                `FNC_BGEU: BrUn = 1'b1;
                default: BrUn = 1'b0;
            endcase
        end
        else begin
            BrUn = 1'b0;
        end

        // ALUSel
        // ALUSel is implemented in ALUdec.v. Here it is instantiated.
        ALUdec ALUdec_inst(
            .opcode(s0s1_inst[6:0]),
            .funct(s0s1_inst[14:12]),
            .add_rshift_type(s0s1_inst[30]),
            .ALUop(ALUSel)
        );

        // MemRW
        // MemRW is 1 if and only if the instruction is a store.
        if (s0s1_inst[6:0] == `OPC_STORE) begin
            MemRW = 1'b1;
        end
        else begin
            MemRW = 1'b0;
        end

        // WBSel
        // WBSel is 0 if and only if the instruction is a load.
        // WBSel is 1 if and only if the instruction is a: Rtype or Itype.
        // WBSel is 2 if and only if the instruction is a: JAL or JALR.
        // In other scenarios, set WBSel to 1.
        if (s0s1_inst[6:0] == `OPC_LOAD) begin
            WBSel = 2'b00;
        end
        else if (s0s1_inst[6:0] == `OPC_ARI_RTYPE ||
                 s0s1_inst[6:0] == `OPC_ARI_ITYPE) begin
            WBSel = 2'b01;
        end
        else if (s0s1_inst[6:0] == `OPC_JAL ||
                 s0s1_inst[6:0] == `OPC_JALR) begin
            WBSel = 2'b10;
        end
        else begin
            WBSel = 2'b01;
        end
    end

endmodule
