// Module: s0_PC_MUX
// Desc:   Provide a mux for the program counter; one is s0_pc_add_4, and the other is the branch target, or s0_pc_alu.
// Inputs: s0_pc_alu: the branch target, or the output from the ALU
//         s0_pc_add_4: the PC + 4
//         PCSel: the signal selecting between the two inputs, which comes from the control unit
// Outputs: s0_pc_next: the next value of the program counter
//

`include "const.vh"

module s0_PC_MUX(
    input [`CPU_INST_BITS-1: 0] s0_pc_alu,
    input [`CPU_INST_BITS-1: 0] s0_pc_add_4,
    input PCSel,
    output [`CPU_DATA_BITS-1: 0] s0_pc_next
)

    assign s0_pc_next = (PCSel == 1'b1) ? s0_pc_alu : s0_pc_add_4;

endmodule