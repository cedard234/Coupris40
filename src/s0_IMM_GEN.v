// Module: s0_IMM_GEN 
// Desc:   The immediate generator for the processor
// Inputs: ImmSel: the immediate select signal, or the OPCODE
//         s0_inst: the instruction to decode the immediate from
// Outputs: s0_Imm: the immediate
//

`include "const.vh"
`include "Opcode.vh"

module s0_IMM_GEN(
    input [6:0] ImmSel, // The immediate select signal, or the OPCODE
    input [`CPU_INST_BITS-1: 0] s0_inst,
    output reg [`CPU_DATA_BITS-1: 0] s0_Imm
);

    always@(*) begin
        case(ImmSel)
            `OPC_NOOP:      s0_Imm = `CPU_DATA_BITS'(0);    // No Operation
            `OPC_LUI:       s0_Imm = {s0_inst[31:12], 12'b0};   //  U type
            `OPC_AUIPC:     s0_Imm = {s0_inst[31:12], 12'b0};   //  U type
            `OPC_JAL:       s0_Imm = {{12{s0_inst[31]}}, s0_inst[19:12], s0_inst[20], s0_inst[30:21], 1'b0}; //   J type
            `OPC_JALR:      s0_Imm = {{20{s0_inst[31]}}, s0_inst[30:20], 1'b0};    //  I type
            `OPC_BRANCH:    s0_Imm = {{20{s0_inst[31]}}, s0_inst[7], s0_inst[30:25], s0_inst[11:8], 1'b0};    //  B type
            `OPC_STORE:     s0_Imm = {{21{s0_inst[31]}}, s0_inst[30:25], s0_inst[11:7]};  //  S type
            `OPC_LOAD:      s0_Imm = {{21{s0_inst[31]}}, s0_inst[30:20]};     //  I type
            `OPC_ARI_RTYPE: s0_Imm = `CPU_DATA_BITS'(0);    //  R type
            `OPC_ARI_ITYPE: s0_Imm = {{21{s0_inst[31]}}, s0_inst[30:20]};    //  I type
            `OPC_CSR:       s0_Imm = {{28{s0_inst[19]}}, s0_inst[18:15]};    //  CSR operation
            default:        s0_Imm = `CPU_DATA_BITS'(0);    
        endcase
    end
endmodule
            