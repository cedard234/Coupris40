// Module: s0_PC_ADD
// Desc:   Outputs the PC + 4
// Inputs: s0_pc: the current value of the program counter    
// Outputs: s0_pc_add_4: s0_pc + 4
//

`include "const.vh"
module s0_PC_ADD(
    input [`CPU_INST_BITS-1: 0] s0_pc,
    output [`CPU_INST_BITS-1: 0] s0_pc_add_4
);

    assign s0_pc_add_4 = s0_pc + 4;

endmodule