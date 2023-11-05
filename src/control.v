// Module: control
// Desc:   The module to control the datapath, including signals from PCSel all the way to WBSel. This module should include the 3 stage delay of the instructions for decoding purposes as well.
// Inputs: s0_inst: the instruction from the first stage
//         BrEq: the signal to determine if the branch is equal
//         BrLT: the signal to determine if the branch is less than
//         s1_alu: the output of the ALU from the first stage. This is included for the CSR instruction.
// Outputs: PCSel: the signal to select the next PC
//          ImmSel: the signal to select the immediate value, or just the OPCODE
//          RegWEN: the signal to determine if the register file should be written to
//          AddrD: the address to write to in the register file
//          BrUn: the signal to determine if the branch is unsigned
//          ASel: the signal to select between the PC and dataA from the register file
//          BSel: the signal to select between dataB from the register file and the immediate value
//          ALUSel: the signal to select the ALU's operation
//          MemRW: the signal to select between a read or write to memory
//          WMask: the signal to select the write mask for the data memory
//          LdU: the signal to determine the format of the data from the data memory
//          WBSel: the signal to select from pc, ALU or memory for the writeback
//          CSR: The value of the CSR register
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
    input [`CPU_DATA_BITS-1: 0] s2_ALU,
    output reg PCSel,
    output reg [6:0] ImmSel,
    output reg RegWEN,
    output reg [4:0] AddrD,
    output reg BrUn,
    output reg ASel,
    output reg BSel,
    output reg [3:0] ALUSel,
    output reg MemRW,
    output reg [3:0] WMask,
    output reg [3:0] LdU,
    output reg [1:0] WBSel,
    output reg [`CPU_DATA_BITS-1: 0] csr
);

    reg [`CPU_INST_BITS-1: 0] s1_inst, s2_inst;

    // The instruction needs to be pipelined:
    always@(posedge clk) begin
        if (reset) begin
            s1_inst <= 0;
            s2_inst <= 0;
        end
        else begin
            s1_inst <= s0_inst;
            s2_inst <= s1_inst;
        end
    end

    always@(*) begin
        // From left to right on the pipeline plot, the signals are:
        // PCSel
        // PC is NOT PC+4 if and only if the instruction is a JAL, JALR or a BRANCH.
        // If the instruction is a branch, it depends on the branch condition.
        if (s1_inst[6:0] == `OPC_JAL ||
            s1_inst[6:0] == `OPC_JALR) begin
            PCSel = 1'b1;
        end
        else if (s1_inst[6:0] == `OPC_BRANCH) begin
            case(s1_inst[14:12])
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
        ImmSel = s0_inst[6:0];

        // RegWEN
        // RegWEN is 1 if and only if the instruction is a: Rtype, Itype, JAL, JALR, or Utype.
        if (s2_inst[6:0] == `OPC_ARI_RTYPE ||
            s2_inst[6:0] == `OPC_ARI_ITYPE ||
            s2_inst[6:0] == `OPC_JAL ||
            s2_inst[6:0] == `OPC_JALR ||
            s2_inst[6:0] == `OPC_LUI ||
            s2_inst[6:0] == `OPC_AUIPC) begin
            RegWEN = 1'b1;
        end
        else begin
            RegWEN = 1'b0;
        end

        // AddrD
        // AddrD is given to the register file only after the instruction has reached the writeback stage.
        AddrD = s2_inst[11:7];

        // ASel
        // ASel is 1 if and only if the instruction is a: Branch, JAL or JALR.
        if (s1_inst[6:0] == `OPC_BRANCH ||
            s1_inst[6:0] == `OPC_JAL ||
            s1_inst[6:0] == `OPC_JALR) begin
            ASel = 1'b1;
        end
        else begin
            ASel = 1'b0;
        end

        // BSel
        // BSel is 1 if and only if the instruction is a: Itype, Stype, Branch, JAL, JALR, LUI or AUIPC.
        if (s1_inst[6:0] == `OPC_ARI_ITYPE ||
            s1_inst[6:0] == `OPC_STORE ||
            s1_inst[6:0] == `OPC_BRANCH ||
            s1_inst[6:0] == `OPC_JAL ||
            s1_inst[6:0] == `OPC_JALR ||
            s1_inst[6:0] == `OPC_LUI ||
            s1_inst[6:0] == `OPC_AUIPC) begin
            BSel = 1'b1;
        end
        else begin
            BSel = 1'b0;
        end

        // BrUn
        // BrUn is 1 if and only if the instruction is a: BLTU or BGEU.
        if (s1_inst[6:0] == `OPC_BRANCH) begin
            case(s1_inst[14:12])
                `FNC_BLTU: BrUn = 1'b1;
                `FNC_BGEU: BrUn = 1'b1;
                default: BrUn = 1'b0;
            endcase
        end
        else begin
            BrUn = 1'b0;
        end

        // MemRW
        // MemRW is 1 if and only if the instruction is a store.
        if (s1_inst[6:0] == `OPC_STORE) begin
            MemRW = 1'b1;
        end
        else begin
            MemRW = 1'b0;
        end

        // WMask
        // WMask is 0000 if not a store
        // WMask is 0001 if SB
        // WMask is 0011 if SH
        // WMask is 1111 if SW
        if (s1_inst[6:0] == `OPC_STORE) begin
            case(s1_inst[14:12])
                `FNC_SB: WMask = 4'b0001;
                `FNC_SH: WMask = 4'b0011;
                `FNC_SW: WMask = 4'b1111;
                default: WMask = 4'b0000;
            endcase
        end
        else begin
            WMask = 4'b0000;
        end

        // LdU
        LdU = s2_inst[14:12];

        // WBSel
        // WBSel is 0 if and only if the instruction is a load.
        // WBSel is 1 if and only if the instruction is a: Rtype or Itype.
        // WBSel is 2 if and only if the instruction is a: JAL or JALR.
        // In other scenarios, set WBSel to 1.
        if (s1_inst[6:0] == `OPC_LOAD) begin
            WBSel = 2'b00;
        end
        else if (s1_inst[6:0] == `OPC_ARI_RTYPE ||
                 s1_inst[6:0] == `OPC_ARI_ITYPE) begin
            WBSel = 2'b01;
        end
        else if (s1_inst[6:0] == `OPC_JAL ||
                 s1_inst[6:0] == `OPC_JALR) begin
            WBSel = 2'b10;
        end
        else begin
            WBSel = 2'b01;
        end
    end

    // ALUSel
    // ALUSel is implemented in ALUdec.v. Here it is instantiated.
    ALUdec ALUdec_inst(
        .opcode(s1_inst[6:0]),
        .funct(s1_inst[14:12]),
        .add_rshift_type(~s1_inst[30]),
        .ALUop(ALUSel)
    );

    // CSR
    always@(posedge clk) begin
        if (reset) begin
        csr <= 0;
        end
        else begin
        if (s1_inst[6:0] == `OPC_CSR) begin
            csr <= s2_ALU;
        end
        end
    end

endmodule
