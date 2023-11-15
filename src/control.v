// Module: control
// Desc:   The module to control the datapath, including signals from PCSel all the way to WBSel. This module should include the 3 stage delay of the instructions for decoding purposes as well.
// Inputs: s0_inst: the instruction from the first stage
//         BrEq: the signal to determine if the branch is equal
//         BrLT: the signal to determine if the branch is less than
//         s2_alu: the output of the ALU from the first stage. This is included for the CSR insruction.
//         s1_dataA: the dataA from the register file
//         s1_dataB: the dataB from the register file
//         s2_dataD: the data to be written to the register file
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
//          s1_dataA_latest: the dataA after done forwarding
//          s1_dataB_latest: the dataB after done forwarding
//          s1_inst_output: the instruction at s1 stage 

`include "const.vh"
`include "Opcode.vh"
`include "ALUop.vh"

module control(
    input clk,
    input reset,
    input [`CPU_INST_BITS-1: 0] s0_inst,
    input BrEq,
    input BrLT,
    input [`CPU_DATA_BITS-1: 0] s1_dataA,
    input [`CPU_DATA_BITS-1: 0] s1_dataB,
    input [`CPU_DATA_BITS-1: 0] s2_dataD,
    input [`CPU_DATA_BITS-1: 0] s2_ALU,
    input [`CPU_DATA_BITS-1: 0] s1_ALU,
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
    output reg [`CPU_DATA_BITS-1: 0] csr,
    output reg [`CPU_DATA_BITS-1: 0] s1_dataA_latest,
    output reg [`CPU_DATA_BITS-1: 0] s1_dataB_latest,
    output reg [`CPU_DATA_BITS-1: 0] s1_inst_output,
    output [1: 0] dmemory_address,
    output reg [`CPU_DATA_BITS-1: 0] s1_dataB_latest_shifted
);

    reg [`CPU_INST_BITS-1: 0] s1_inst, s2_inst;

    reg [`CPU_INST_BITS-1: 0] s1_inst_next;
    // The instruction needs to be pipelined:
    always@(posedge clk) begin
        if (reset) begin
            s1_inst <= 0;
            s2_inst <= 0;
        end
        else begin
            s2_inst <= s1_inst;
            s1_inst <= s1_inst_next;
        end
    end

    always@(*) begin
        // s1_inst_next: flush the pipeline if the branch is taken, or if the instruction is a JAL or JALR.
        if (s1_inst[6:0] == `OPC_BRANCH) begin
            case(s1_inst[14:12])
                `FNC_BEQ: s1_inst_next = (BrEq) ? `INSTR_NOP : s0_inst;
                `FNC_BNE: s1_inst_next = (~BrEq) ? `INSTR_NOP : s0_inst;
                `FNC_BLT: s1_inst_next = (BrLT) ? `INSTR_NOP : s0_inst;
                `FNC_BGE: s1_inst_next = (~BrLT) ? `INSTR_NOP : s0_inst;
                `FNC_BLTU: s1_inst_next = (BrLT) ? `INSTR_NOP : s0_inst;
                `FNC_BGEU: s1_inst_next = (~BrLT) ? `INSTR_NOP : s0_inst;
                default: s1_inst_next = s0_inst;
            endcase
        end
        else if (s1_inst[6:0] == `OPC_JAL) begin
            s1_inst_next = `INSTR_NOP;
        end
        else if (s1_inst[6:0] == `OPC_JALR) begin
            s1_inst_next = `INSTR_NOP;
        end
        else begin
            s1_inst_next = s0_inst;
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
            s2_inst[6:0] == `OPC_AUIPC ||
            s2_inst[6:0] == `OPC_LOAD) begin
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
            s1_inst[6:0] == `OPC_AUIPC) begin
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
            s1_inst[6:0] == `OPC_AUIPC ||
            s1_inst[6:0] == `OPC_LOAD) begin
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
        // WMask is 0001, 0010, 0100, 1000 if SB
        // WMask is 0011 if SH
        // WMask is 1111 if SW
        if (s1_inst[6:0] == `OPC_STORE) begin
            case(s1_inst[14:12])
                `FNC_SB: begin
                    case (s1_ALU[1:0])
                        2'b00: begin WMask = 4'b0001; s1_dataB_latest_shifted = s1_dataB_latest; end
                        2'b01: begin WMask = 4'b0010; s1_dataB_latest_shifted = s1_dataB_latest << 8; end
                        2'b10: begin WMask = 4'b0100; s1_dataB_latest_shifted = s1_dataB_latest << 16; end
                        2'b11: begin WMask = 4'b1000; s1_dataB_latest_shifted = s1_dataB_latest << 24; end
                        default: WMask = 4'b0000;
                    endcase
                end
                `FNC_SH: begin
                    case (s1_ALU[1:0])
                        2'b00: begin WMask = 4'b0011; s1_dataB_latest_shifted = s1_dataB_latest; end
                        2'b01: begin WMask = 4'b0110; s1_dataB_latest_shifted = s1_dataB_latest << 8; end
                        2'b10: begin WMask = 4'b1100; s1_dataB_latest_shifted = s1_dataB_latest << 16; end
                        2'b11: begin WMask = 4'b1000; s1_dataB_latest_shifted = s1_dataB_latest << 24; end
                        default: WMask = 4'b0000;
                    endcase
                end
                `FNC_SW: begin
                    case (s1_ALU[1:0])
                        2'b00: begin WMask = 4'b1111; s1_dataB_latest_shifted = s1_dataB_latest; end
                        2'b01: begin WMask = 4'b1110; s1_dataB_latest_shifted = s1_dataB_latest << 8; end
                        2'b10: begin WMask = 4'b1100; s1_dataB_latest_shifted = s1_dataB_latest << 16; end
                        2'b11: begin WMask = 4'b1000; s1_dataB_latest_shifted = s1_dataB_latest << 24; end
                        default: WMask = 4'b0000;
                    endcase
                end
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
        if (s2_inst[6:0] == `OPC_LOAD) begin
            WBSel = 2'b00;
        end
        else if (s2_inst[6:0] == `OPC_ARI_RTYPE ||
                 s2_inst[6:0] == `OPC_ARI_ITYPE) begin
            WBSel = 2'b01;
        end
        else if (s2_inst[6:0] == `OPC_JAL ||
                 s2_inst[6:0] == `OPC_JALR) begin
            WBSel = 2'b10;
        end
        else begin
            WBSel = 2'b01;
        end

        // Data Forwarding
        // When either dataA or dataB address coincides with the address of the register to be written to, the data after writeback stage is forwarded to the ALU.
        // Only do dataA forwarding when the instruction at s1 is R, I, S or B, and the instruction at s2 is I, R, auipc or lui.
        if ((s1_inst[6:0] == `OPC_ARI_RTYPE ||
            s1_inst[6:0] == `OPC_ARI_ITYPE ||
            s1_inst[6:0] == `OPC_STORE ||
            s1_inst[6:0] == `OPC_BRANCH ||
            s1_inst[6:0] == `OPC_LOAD ||
            s1_inst[6:0] == `OPC_AUIPC ||
            s1_inst[6:0] == `OPC_JALR) && 
            (s2_inst[6:0] == `OPC_ARI_RTYPE ||
            s2_inst[6:0] == `OPC_ARI_ITYPE ||
            s2_inst[6:0] == `OPC_AUIPC ||
            s2_inst[6:0] == `OPC_LUI ||
            s2_inst[6:0] == `OPC_LOAD)) begin
            if ((s1_inst[19:15] == AddrD) && AddrD != 0) begin
                s1_dataA_latest = s2_dataD;
            end
            else begin
                s1_dataA_latest = s1_dataA;
            end
        end
        else begin
            s1_dataA_latest = s1_dataA;
        end

        // Only do dataB forwarding when the instruction at s1 is R, S or B.
        if ((s1_inst[6:0] == `OPC_ARI_RTYPE ||
            s1_inst[6:0] == `OPC_ARI_ITYPE ||
            s1_inst[6:0] == `OPC_STORE ||
            s1_inst[6:0] == `OPC_BRANCH ||
            s1_inst[6:0] == `OPC_LOAD ||
            s1_inst[6:0] == `OPC_AUIPC ||
            s1_inst[6:0] == `OPC_JALR) && 
            (s2_inst[6:0] == `OPC_ARI_RTYPE ||
            s2_inst[6:0] == `OPC_ARI_ITYPE ||
            s2_inst[6:0] == `OPC_AUIPC ||
            s2_inst[6:0] == `OPC_LUI||
            s2_inst[6:0] == `OPC_LOAD)) begin
            if ((s1_inst[24:20] == AddrD) && AddrD != 0) begin
                s1_dataB_latest = s2_dataD;
            end
            else begin
                s1_dataB_latest = s1_dataB;
            end
        end
        else begin
            s1_dataB_latest = s1_dataB;
        end
    end

    // ALUSel
    // ALUSel is implemented in ALUdec.v. Here it is instantiated.
    ALUdec ALUdec_inst(
        .opcode(s1_inst[6:0]),
        .funct(s1_inst[14:12]),
        .add_rshift_type(s1_inst[30]),
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

assign s1_inst_output = s1_inst;

// We need memory address to do memory address alignment process.
assign dmemory_address = s2_ALU[1:0];


endmodule
